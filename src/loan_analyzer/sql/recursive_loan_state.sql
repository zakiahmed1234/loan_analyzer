/* 
SIMPLIFIED recursive_loan_state.sql
DuckDB optimized, removed lender-specific and partition logic.
*/

-- 1️⃣ Build monthly loan calendar
CREATE OR REPLACE TABLE loan_calendar AS
WITH bounds AS (
    SELECT 
        DATE_TRUNC('month', MIN(CAST(origination_date AS DATE)))::TIMESTAMP as min_date,
        DATE_TRUNC('month', MAX(CAST(maturity_date AS DATE)) + INTERVAL '12 months')::TIMESTAMP as max_date
    FROM loans
),
months AS (
    SELECT generate_series AS period_start_ts
    FROM bounds, generate_series(bounds.min_date, bounds.max_date, INTERVAL '1 month')
)
SELECT
    l.loan_id,
    m.period_start_ts::DATE as period_start,
    (m.period_start_ts + INTERVAL '1 month')::DATE AS period_end,
    ROW_NUMBER() OVER (PARTITION BY l.loan_id ORDER BY m.period_start_ts) AS period_number
FROM loans l
JOIN months m ON m.period_start_ts::DATE >= DATE_TRUNC('month', CAST(l.origination_date AS DATE))::DATE
             AND m.period_start_ts::DATE <= DATE_TRUNC('month', CAST(l.maturity_date AS DATE) + INTERVAL '12 months')::DATE;

-- 2️⃣ Aggregate payments, write-offs, and penalties per loan-period
CREATE OR REPLACE TABLE transactions_by_period AS
SELECT
    loan_id,
    DATE_TRUNC('month', CAST(actual_payment_date AS DATE))::DATE AS period_start,
    SUM(actual_total_amount)::DOUBLE AS cash_paid,
    SUM(write_off_amount)::DOUBLE AS write_off_amt,
    SUM(penalty_amount)::DOUBLE AS penalty_amt
FROM actual_payments
GROUP BY ALL;

-- 3️⃣ Interest schedule per period
CREATE OR REPLACE TABLE interest_schedule AS
SELECT
    c.loan_id,
    c.period_start,
    (l.interest_rate / 1200.0)::DOUBLE AS monthly_rate
FROM loan_calendar c
JOIN loans l ON c.loan_id = l.loan_id;

-- 4️⃣ Recursive loan state engine
CREATE OR REPLACE TABLE loan_state AS
WITH RECURSIVE balance_engine AS (
    SELECT
        l.loan_id,
        c.period_number,
        c.period_start,
        l.loan_amount::DOUBLE AS opening_principal,
        0.0::DOUBLE AS interest_accrued,
        0.0::DOUBLE AS cash_received,
        0.0::DOUBLE AS write_off_occurred,
        l.loan_amount::DOUBLE AS closing_principal
    FROM loans l
    JOIN loan_calendar c ON l.loan_id = c.loan_id AND c.period_number = 1

    UNION ALL

    SELECT
        b.loan_id,
        c.period_number,
        c.period_start,
        b.closing_principal AS opening_principal,
        (b.closing_principal * i.monthly_rate)::DOUBLE AS interest_accrued,
        COALESCE(p.cash_paid, 0.0)::DOUBLE AS cash_received,
        COALESCE(p.write_off_amt, 0.0)::DOUBLE AS write_off_occurred,
        GREATEST(
            b.closing_principal 
            - GREATEST(COALESCE(p.cash_paid, 0.0) - (b.closing_principal * i.monthly_rate) - COALESCE(p.penalty_amt, 0.0), 0)
            - COALESCE(p.write_off_amt, 0.0),
            0
        )::DOUBLE AS closing_principal
    FROM balance_engine b
    JOIN loan_calendar c ON b.loan_id = c.loan_id AND c.period_number = b.period_number + 1
    JOIN interest_schedule i ON b.loan_id = i.loan_id AND c.period_start = i.period_start
    LEFT JOIN transactions_by_period p ON b.loan_id = p.loan_id AND c.period_start = p.period_start
    WHERE b.closing_principal > 0.01 
)
SELECT * FROM balance_engine;
