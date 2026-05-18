/* We calculate the average time between loans for repeat borrowers. Specifically, for each repeat borrower, we calculate the time between each consecutive loan origination date then average it. */

--
-- WITH LoanIntervals AS (
--     SELECT 
--         borrower_id,
--         origination_date,
--         -- Sequence the loans so you know which interval is which (1st to 2nd, etc.)
--         ROW_NUMBER() OVER (PARTITION BY borrower_id ORDER BY origination_date ASC) as loan_seq,
--         LAG(origination_date) OVER (
--             PARTITION BY borrower_id 
--             ORDER BY origination_date ASC
--         ) as previous_loan_date
--     FROM loans
-- ),
-- CalculatedDays AS (
--     SELECT 
--         borrower_id,
--         origination_date,
--         loan_seq,
--         -- Standard SQL date subtraction (results in days)
--         (origination_date - previous_loan_date) as days_since_last_loan
--     FROM LoanIntervals
--     WHERE previous_loan_date IS NOT NULL
-- )
-- -- Aggregate per borrower
-- SELECT 
--     borrower_id,
--     COUNT(*) as total_repeat_loans,
--     ROUND(AVG(days_since_last_loan), 1) as avg_days_between_loans,
--     MIN(days_since_last_loan) as shortest_gap,
--     MAX(days_since_last_loan) as longest_gap
-- FROM CalculatedDays
-- GROUP BY borrower_id
-- ORDER BY avg_days_between_loans ASC;


WITH LoanIntervals AS (
    SELECT
        borrower_id,
        CAST(origination_date AS DATE) as origination_date,
        ROW_NUMBER() OVER (PARTITION BY borrower_id ORDER BY origination_date ASC) as loan_seq,
        LAG(CAST(origination_date AS DATE)) OVER (
            PARTITION BY borrower_id
            ORDER BY origination_date ASC
        ) as previous_loan_date
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
),
CalculatedDays AS (
    SELECT
        borrower_id,
        origination_date,
        loan_seq,
        date_diff('day', previous_loan_date, origination_date) as days_since_last_loan
    FROM LoanIntervals
    WHERE previous_loan_date IS NOT NULL
)
SELECT
    borrower_id,
    COUNT(*) as total_repeat_loans,
    ROUND(AVG(CAST(days_since_last_loan AS DOUBLE)), 1) as avg_days_between_loans,
    MIN(days_since_last_loan) as shortest_gap,
    MAX(days_since_last_loan) as longest_gap
FROM CalculatedDays
GROUP BY borrower_id
ORDER BY avg_days_between_loans ASC
