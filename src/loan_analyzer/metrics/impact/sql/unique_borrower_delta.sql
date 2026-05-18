-- WITH FirstLoans AS (
--     -- Identify the very first loan date for every borrower
--     SELECT 
--         borrower_id, 
--         MIN(origination_date) as first_loan_date
--     FROM loans
--     GROUP BY borrower_id
-- ),
-- MonthlyStats AS (
--     -- Truncate to the month and count new entries
--     SELECT
--         DATE_TRUNC('month', CAST(first_loan_date AS DATE)) as signup_month,
--         COUNT(borrower_id) as new_borrowers_this_month
--     FROM FirstLoans
--     GROUP BY 1
-- )
-- SELECT 
--     signup_month,
--     -- This is your derivative (monthly growth)
--     new_borrowers_this_month,
--     -- This is the cumulative total
--     SUM(new_borrowers_this_month) OVER (ORDER BY signup_month ASC) as total_borrowers_to_date,
--     -- Extra: Month-over-Month growth percentage
--     ROUND(
--         (new_borrowers_this_month - LAG(new_borrowers_this_month) OVER (ORDER BY signup_month ASC))::numeric
--         / NULLIF(LAG(new_borrowers_this_month) OVER (ORDER BY signup_month ASC), 0) * 100.0,
--     2) as second_deriv_growth
-- FROM MonthlyStats
-- ORDER BY 1 DESC;

WITH FirstLoans AS (
    -- Identify the very first loan date for every borrower
    SELECT
        borrower_id,
        MIN(CAST(origination_date AS DATE)) as first_loan_date
    FROM loans
    WHERE
        lender_id = ${lender_id}
        AND (
            year > ${start_year} OR
            (year = ${start_year} AND month > ${start_month}) OR
            (year = ${start_year} AND month = ${start_month} AND day >= ${start_day})
        )
        AND (
            year < ${end_year} OR
            (year = ${end_year} AND month < ${end_month}) OR
            (year = ${end_year} AND month = ${end_month} AND day <= ${end_day})
        )
    GROUP BY borrower_id
),
MonthlyStats AS (
    -- Truncate to the month and count new entries
    -- Explicitly cast to DATE so it doesn't stay as a TIMESTAMP
    SELECT
        CAST(DATE_TRUNC('month', first_loan_date) AS DATE) as signup_month,
        COUNT(borrower_id) as new_borrowers_this_month
    FROM FirstLoans
    GROUP BY 1
)
SELECT 
    signup_month,
    new_borrowers_this_month,
    -- Cumulative total
    SUM(new_borrowers_this_month) OVER (ORDER BY signup_month ASC) as total_borrowers_to_date,
    -- Month-over-Month growth percentage
    -- Replaced ::numeric with CAST(... AS DOUBLE)
    ROUND(
        CAST(new_borrowers_this_month - LAG(new_borrowers_this_month) OVER (ORDER BY signup_month ASC) AS DOUBLE)
        / NULLIF(CAST(LAG(new_borrowers_this_month) OVER (ORDER BY signup_month ASC) AS DOUBLE), 0) * 100.0,
    2) as mom_growth_pct
FROM MonthlyStats
ORDER BY 1 DESC;
