/* This calculates write offs, prepayment rates, and penalty rates over time, whilst keeping loan id for further integration downstream */

--
-- --- 1️⃣ WRITE-OFF MONITORING
-- -- Tracks individual write-off events and their impact relative to the original loan size.
-- CREATE OR REPLACE VIEW reporting_write_offs AS
-- SELECT
--     ls.period_start,
--     ls.loan_id,
--     ls.write_off_occurred AS write_off_amount,
--     l.loan_amount AS original_principal,
--     (ls.write_off_occurred / NULLIF(l.loan_amount, 0))::DOUBLE AS monthly_write_off_rate
-- FROM loan_state ls
-- JOIN loans l ON ls.loan_id = l.loan_id
-- WHERE ls.write_off_occurred > 0;
--
-- --- 2️⃣ PREPAYMENT RATES
-- -- Measures "Principal Speed" by identifying cash received in excess of the month's requirements.
-- CREATE OR REPLACE VIEW reporting_prepayments AS
-- SELECT
--     id.loan_id,
--     id.scheduled_instalment_date,
--     sb.scheduled_amount,
--     ls.cash_received,
--     -- Calculate the surplus cash that went toward principal reduction
--     GREATEST(ls.cash_received - (ls.interest_accrued + sb.scheduled_amount), 0)::DOUBLE AS prepayment_extra_principal,
--     id.flag_prepayment_this_month
-- FROM instalment_delinquency id
-- JOIN loan_state ls 
--     ON id.loan_id = ls.loan_id 
--     AND DATE_TRUNC('month', CAST(id.scheduled_instalment_date AS DATE)) = ls.period_start
-- JOIN sched_base sb
--     ON id.loan_id = sb.loan_id 
--     AND id.scheduled_instalment_date = sb.scheduled_instalment_date
-- WHERE id.flag_prepayment_this_month = 1;
--
-- --- 3️⃣ PENALTIES OVER TIME
-- -- Tracks the collection of late fees and penalties per loan period.
-- CREATE OR REPLACE VIEW reporting_penalties AS
-- SELECT
--     t.period_start,
--     t.loan_id,
--     t.penalty_amt AS penalty_amount_collected,
--     ls.opening_principal,
--     -- Penalty Yield: Impact of penalties relative to the outstanding balance
--     (t.penalty_amt / NULLIF(ls.opening_principal, 0))::DOUBLE AS penalty_yield_rate
-- FROM transactions_by_period t
-- JOIN loan_state ls 
--     ON t.loan_id = ls.loan_id 
--     AND t.period_start = ls.period_start
-- WHERE t.penalty_amt > 0;
--
-- --- 4️⃣ OPTIONAL: SUMMARY AGGREGATION
-- -- This rolls up all three metrics by month for a portfolio-level view.
-- CREATE OR REPLACE VIEW monthly_portfolio_performance AS
-- SELECT
--     p.period_start,
--     COUNT(DISTINCT p.loan_id) AS active_loans,
--     SUM(COALESCE(wo.write_off_amount, 0)) AS total_write_offs,
--     SUM(COALESCE(pp.prepayment_extra_principal, 0)) AS total_prepayments,
--     SUM(COALESCE(pn.penalty_amount_collected, 0)) AS total_penalties
-- FROM (SELECT DISTINCT period_start, loan_id FROM loan_state) p
-- LEFT JOIN reporting_write_offs wo ON p.loan_id = wo.loan_id AND p.period_start = wo.period_start
-- LEFT JOIN reporting_prepayments pp ON p.loan_id = pp.loan_id AND p.period_start = DATE_TRUNC('month', CAST(pp.scheduled_instalment_date AS DATE))
-- LEFT JOIN reporting_penalties pn ON p.loan_id = pn.loan_id AND p.period_start = pn.period_start
-- GROUP BY 1

WITH 
-- 1️⃣ Build monthly loan calendar
loan_calendar AS (
    SELECT
        l.loan_id,
        CAST(gs.period_date AS DATE) AS period_start,
        CAST(date_add('month', 1, gs.period_date) AS DATE) AS period_end,
        ROW_NUMBER() OVER (PARTITION BY l.loan_id ORDER BY gs.period_date) AS period_number
    FROM loans l
    CROSS JOIN UNNEST(
        sequence(
            DATE_TRUNC('month', CAST(l.origination_date AS DATE)),
            DATE_TRUNC('month', date_add('month', 120, CAST(l.origination_date AS DATE))),
            INTERVAL '1' MONTH
        )
    ) AS gs(period_date)
    WHERE l.lender_id = $lender_id
      AND l.year BETWEEN $start_year AND $end_year
),

-- 2️⃣ Aggregate payments, write-offs, and penalties per loan-period
transactions_by_period AS (
    SELECT
        loan_id,
        CAST(DATE_TRUNC('month', CAST(actual_payment_date AS DATE)) AS DATE) AS period_start,
        SUM(CAST(actual_total_amount AS DOUBLE)) AS cash_paid,
        SUM(CAST(write_off_amount AS DOUBLE)) AS write_off_amt,
        SUM(CAST(penalty_amount AS DOUBLE)) AS penalty_amt
    FROM actual_payments
    WHERE lender_id = $lender_id
      AND year BETWEEN $start_year AND $end_year
    GROUP BY 1, 2
),

-- 3️⃣ Reporting: Write Offs
reporting_write_offs AS (
    SELECT
        CAST(ls.period_start AS DATE) AS period_start,
        ls.loan_id,
        ls.write_off_occurred AS write_off_amount,
        l.loan_amount AS original_principal,
        CAST(ls.write_off_occurred AS DOUBLE) / NULLIF(CAST(l.loan_amount AS DOUBLE), 0) AS monthly_write_off_rate
    FROM loan_state ls
    JOIN loans l ON ls.loan_id = l.loan_id
    WHERE l.lender_id = $lender_id
      AND ls.lender_id = $lender_id -- Required for Injected Projection
      AND ls.write_off_occurred > 0
      AND l.year BETWEEN $start_year AND $end_year
),

-- 4️⃣ Reporting: Prepayments
reporting_prepayments AS (
    SELECT
        id.loan_id,
        id.scheduled_instalment_date,
        (CAST(sr.scheduled_principal AS DOUBLE) + 
         CAST(sr.scheduled_interest AS DOUBLE) + 
         CAST(sr.scheduled_fees AS DOUBLE) + 
         CAST(sr.scheduled_vat AS DOUBLE)) AS scheduled_amount,
        ls.cash_received,
        GREATEST(
            CAST(ls.cash_received AS DOUBLE) - (
                CAST(ls.interest_accrued AS DOUBLE) + 
                (CAST(sr.scheduled_principal AS DOUBLE) + 
                 CAST(sr.scheduled_interest AS DOUBLE) + 
                 CAST(sr.scheduled_fees AS DOUBLE) + 
                 CAST(sr.scheduled_vat AS DOUBLE))
            ), 0
        ) AS prepayment_extra_principal,
        id.flag_prepayment_this_month
    FROM instalment_delinquency id
    JOIN loan_state ls
        ON id.loan_id = ls.loan_id
        AND CAST(DATE_TRUNC('month', CAST(id.scheduled_instalment_date AS DATE)) AS DATE) = CAST(ls.period_start AS DATE)
    JOIN scheduled_repayments sr
        ON id.loan_id = sr.loan_id
        AND CAST(id.scheduled_instalment_date AS DATE) = CAST(sr.scheduled_instalment_date AS DATE)
    WHERE sr.lender_id = $lender_id
        AND ls.lender_id = $lender_id -- Required for Injected Projection
        AND id.flag_prepayment_this_month = 1
        AND sr.year BETWEEN $start_year AND $end_year
),

-- 5️⃣ Reporting: Penalties
reporting_penalties AS (
    SELECT
        t.period_start,
        t.loan_id,
        t.penalty_amt AS penalty_amount_collected,
        ls.opening_principal,
        CAST(t.penalty_amt AS DOUBLE) / NULLIF(CAST(ls.opening_principal AS DOUBLE), 0) AS penalty_yield_rate
    FROM transactions_by_period t
    JOIN loan_state ls 
        ON t.loan_id = ls.loan_id 
        AND t.period_start = CAST(ls.period_start AS DATE)
    WHERE ls.lender_id = $lender_id
      AND t.penalty_amt > 0
      AND ls.year BETWEEN $start_year AND $end_year
)

-- FINAL OUTPUT
SELECT
    p.period_start,
    COUNT(DISTINCT p.loan_id) AS active_loans,
    SUM(COALESCE(wo.write_off_amount, 0)) AS total_write_offs,
    SUM(COALESCE(pp.prepayment_extra_principal, 0)) AS total_prepayments,
    SUM(COALESCE(pn.penalty_amount_collected, 0)) AS total_penalties
FROM (
    SELECT DISTINCT CAST(period_start AS DATE) as period_start, loan_id 
    FROM loan_state 
    WHERE lender_id = $lender_id
      AND year BETWEEN $start_year AND $end_year
) p
LEFT JOIN reporting_write_offs wo 
    ON p.loan_id = wo.loan_id 
    AND p.period_start = wo.period_start
LEFT JOIN reporting_prepayments pp 
    ON p.loan_id = pp.loan_id 
    AND p.period_start = CAST(DATE_TRUNC('month', CAST(pp.scheduled_instalment_date AS DATE)) AS DATE)
LEFT JOIN reporting_penalties pn 
    ON p.loan_id = pn.loan_id 
    AND p.period_start = pn.period_start
GROUP BY 1
ORDER BY 1 DESC;
