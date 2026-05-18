WITH 
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
    WHERE l.lender_id = ${lender_id}
      AND ls.lender_id = ${lender_id}
      AND ls.write_off_occurred > 0
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
        AND DATE_TRUNC('month', CAST(id.scheduled_instalment_date AS DATE)) = CAST(ls.period_start AS DATE)
    JOIN scheduled_repayments sr
        ON id.loan_id = sr.loan_id
        AND CAST(id.scheduled_instalment_date AS DATE) = CAST(sr.scheduled_instalment_date AS DATE)
    WHERE sr.lender_id = ${lender_id}
        AND ls.lender_id = ${lender_id}
        AND id.flag_prepayment_this_month = 1
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
    WHERE ls.lender_id = ${lender_id}
      AND t.penalty_amt > 0
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
    WHERE lender_id = ${lender_id}
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
