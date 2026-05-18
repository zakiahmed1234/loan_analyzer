/* In this we determine the trend of origination fee as a % of loan amount over time. */
/*
SELECT 
    DATE_TRUNC('month', CAST(origination_date AS DATE)) AS origination_month,
    SUM(origination_fee_amount) AS total_origination_fees,
    SUM(loan_amount) AS total_loan_amount,
    -- The Sigma Orig Fee / Sigma Loan Amount calculation
    100 * SUM(origination_fee_amount) / NULLIF(SUM(loan_amount), 0) AS fee_yield_ratio_pct
FROM 
    loans
GROUP BY 
    1
ORDER BY 
    1 DESC;
*/

SELECT 
    /* Cast the string to a DATE before truncating */
    DATE_TRUNC('month', CAST(origination_date AS DATE)) AS origination_month,
    SUM(origination_fee_amount) AS total_origination_fees,
    SUM(loan_amount) AS total_loan_amount,
    -- The Sigma Orig Fee / Sigma Loan Amount calculation
    100.0 * SUM(origination_fee_amount) / NULLIF(SUM(loan_amount), 0) AS fee_yield_ratio_pct
FROM
    (SELECT * FROM loans WHERE lender_id = ${lender_id})
WHERE
      (
          year > ${start_year} OR
          (year = ${start_year} AND month > ${start_month}) OR
          (year = ${start_year} AND month = ${start_month} AND day >= ${start_day})
      )
      AND (
          year < ${end_year} OR
          (year = ${end_year} AND month < ${end_month}) OR
          (year = ${end_year} AND month = ${end_month} AND day <= ${end_day})
      )
GROUP BY 
    1
ORDER BY 
    1 DESC;
