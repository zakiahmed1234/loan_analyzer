-- REBUILT: simplified instalment_delinquency_maker.sql
-- DuckDB optimized, lender-specific and partition logic removed.

WITH sched_base AS (
    SELECT
        loan_id,
        CAST(scheduled_instalment_date AS DATE) AS scheduled_instalment_date,
        CAST(
            COALESCE(scheduled_principal, 0) + 
            COALESCE(scheduled_interest, 0) + 
            COALESCE(scheduled_fees, 0) + 
            COALESCE(scheduled_vat, 0) 
        AS DOUBLE) AS scheduled_amount
    FROM scheduled_repayments
),

cumulative_sched AS (
    SELECT 
        loan_id,
        scheduled_instalment_date,
        scheduled_amount,
        SUM(scheduled_amount) OVER (PARTITION BY loan_id ORDER BY scheduled_instalment_date) AS cumulative_due
    FROM sched_base
),

cumulative_pays AS (
    SELECT 
        loan_id,
        CAST(actual_payment_date AS DATE) AS actual_payment_date,
        CAST(actual_total_amount AS DOUBLE) AS actual_total_amount,
        SUM(CAST(actual_total_amount AS DOUBLE)) OVER (PARTITION BY loan_id ORDER BY actual_payment_date) AS cumulative_paid
    FROM actual_payments
    WHERE CAST(actual_total_amount AS DOUBLE) > 0 
),

fully_paid_dates AS (
    SELECT 
        s.loan_id,
        s.scheduled_instalment_date,
        s.scheduled_amount,
        s.cumulative_due,
        MIN(p.actual_payment_date) AS real_payment_date
    FROM cumulative_sched s
    LEFT JOIN cumulative_pays p 
        ON s.loan_id = p.loan_id 
        AND p.cumulative_paid >= s.cumulative_due
    GROUP BY ALL
)

SELECT
    f.loan_id,
    l.lender_id,
    f.scheduled_instalment_date,
    ls.closing_principal,
    f.real_payment_date,

    -- PARTITIONS
    EXTRACT(YEAR FROM CAST(f.scheduled_instalment_date AS DATE))::INTEGER AS year,
    EXTRACT(MONTH FROM CAST(f.scheduled_instalment_date AS DATE))::INTEGER AS month,
    EXTRACT(DAY FROM CAST(f.scheduled_instalment_date AS DATE))::INTEGER AS day,

    -- DELINQUENCY FLAGS
    CASE 
        WHEN ls.closing_principal <= 0.01 THEN 0 
        ELSE date_diff('day', 
                       CAST(f.scheduled_instalment_date AS DATE), 
                       COALESCE(f.real_payment_date, CURRENT_DATE)) 
    END AS days_past_due,

    -- EVENT FLAGS
    CASE WHEN ls.write_off_occurred > 0 THEN 1 ELSE 0 END AS flag_write_off_this_month,

    -- PREPAYMENT FLAG
    CASE 
        WHEN ls.cash_received > (ls.interest_accrued + f.scheduled_amount + 0.01) THEN 1 
        ELSE 0 
    END AS flag_prepayment_this_month,

    -- STATUS CATEGORY
    CASE
        WHEN ls.closing_principal <= 0.01 AND ls.write_off_occurred > 0 THEN 'written off'
        WHEN ls.closing_principal <= 0.01 THEN 'paid off'
        WHEN date_diff('day', CAST(f.scheduled_instalment_date AS DATE), COALESCE(f.real_payment_date, CURRENT_DATE)) >= 90 THEN 'dpd 90+'
        WHEN date_diff('day', CAST(f.scheduled_instalment_date AS DATE), COALESCE(f.real_payment_date, CURRENT_DATE)) >= 60 THEN 'dpd 60-89'
        WHEN date_diff('day', CAST(f.scheduled_instalment_date AS DATE), COALESCE(f.real_payment_date, CURRENT_DATE)) >= 30 THEN 'dpd 30-59'
        WHEN date_diff('day', CAST(f.scheduled_instalment_date AS DATE), COALESCE(f.real_payment_date, CURRENT_DATE)) > 0  THEN 'dpd 1-29'
        ELSE 'current'
    END AS dpd_category

FROM fully_paid_dates f
JOIN loans l ON f.loan_id = l.loan_id
LEFT JOIN loan_state ls
    ON f.loan_id = ls.loan_id
    AND date_trunc('month', CAST(f.scheduled_instalment_date AS DATE)) = CAST(date_trunc('month', CAST(ls.period_start AS DATE)) AS DATE);
