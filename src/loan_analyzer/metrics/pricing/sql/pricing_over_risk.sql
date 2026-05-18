/* In this we look at how pricing is influenced by portfolio risk levels. In particular, for each vintage, we record the distribution of loan grades, and then aggregate weighted principal and fee statistics for each loan grade in that vintage.*/
--
-- WITH monthly_totals AS (
--     SELECT 
--         DATE_TRUNC('month', origination_date) AS origination_month,
--         SUM(loan_amount) AS total_monthly_volume
--     from loans
--     GROUP BY 1
-- )
-- SELECT 
--     l.origination_month,
--     l.loan_grade,
--     -- Volume & Proportion
--     SUM(l.loan_amount) AS grade_volume,
--     ROUND(SUM(l.loan_amount) / m.total_monthly_volume * 100, 2) AS pct_of_monthly_volume,
--     
--     -- Weighted Interest
--     ROUND(SUM(l.interest_rate * l.loan_amount) / NULLIF(SUM(l.loan_amount), 0), 2) AS wtd_avg_interest_rate,
--     
--     -- Weighted Fees
--     ROUND(SUM(l.origination_fee_amount * l.loan_amount) / NULLIF(SUM(l.loan_amount), 0), 2) AS wtd_avg_orig_fee
-- FROM (
--     SELECT *, DATE_TRUNC('month', origination_date) AS origination_month 
--     from loans
-- ) l
-- JOIN monthly_totals m ON l.origination_month = m.origination_month
-- GROUP BY 1, 2, m.total_monthly_volume
-- ORDER BY 1 DESC, 2 ASC;


WITH monthly_totals AS (
    SELECT
        DATE_TRUNC('month', CAST(origination_date AS DATE)) AS origination_month,
        SUM(loan_amount) AS total_monthly_volume
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
    GROUP BY 1
)
SELECT 
    l.origination_month,
    l.loan_grade,
    -- Volume & Proportion
    SUM(l.loan_amount) AS grade_volume,
    -- Use 100.0 to force float division
    ROUND(SUM(l.loan_amount) * 100.0 / m.total_monthly_volume, 2) AS pct_of_monthly_volume,
    
    -- Weighted Interest
    ROUND(SUM(l.interest_rate * l.loan_amount) / NULLIF(SUM(l.loan_amount), 0), 2) AS wtd_avg_interest_rate,
    
    -- Weighted Fees
    ROUND(SUM(l.origination_fee_amount * l.loan_amount) / NULLIF(SUM(l.loan_amount), 0), 2) AS wtd_avg_orig_fee
FROM (
    SELECT *, DATE_TRUNC('month', CAST(origination_date AS DATE)) AS origination_month
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
) l
JOIN monthly_totals m ON l.origination_month = m.origination_month
GROUP BY 1, 2, m.total_monthly_volume
ORDER BY 1 DESC, 2 ASC;
