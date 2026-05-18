/* We track the yield curve evolution. Specifically, group all loans from a specific origination month by month of maturity. Then for all loans that share a month of maturity, we calculate a weighted average as our yield. We then range this over all origination months.*/


--
-- SELECT 
--     DATE_TRUNC('month', origination_date) AS origination_vintage,
--     DATE_TRUNC('month', maturity_date) AS maturity_month,
--     -- Weighted Average Interest Rate Calculation: SUM(Principal * Rate) / SUM(Principal)
--     SUM(loan_amount * interest_rate) / NULLIF(SUM(loan_amount), 0) AS weighted_avg_yield,
--     SUM(loan_amount) AS total_principal_volume,
--     COUNT(loan_id) AS loan_count
-- FROM 
--     loans
-- GROUP BY 
--     1, 2
-- ORDER BY 
--     1 DESC, 
--     2 ASC;


SELECT 
    DATE_TRUNC('month', CAST(origination_date AS DATE)) AS origination_vintage,
    DATE_TRUNC('month', CAST(maturity_date AS DATE)) AS maturity_month,
    -- Weighted Average Interest Rate
    SUM(loan_amount * interest_rate) / NULLIF(SUM(loan_amount), 0) AS weighted_avg_yield,
    SUM(loan_amount) AS total_principal_volume,
    COUNT(loan_id) AS loan_count
FROM
    (SELECT * FROM loans WHERE lender_id = $lender_id)
WHERE
      (
          year > $start_year OR
          (year = $start_year AND month > $start_month) OR
          (year = $start_year AND month = $start_month AND day >= $start_day)
      )
      AND (
          year < $end_year OR
          (year = $end_year AND month < $end_month) OR
          (year = $end_year AND month = $end_month AND day <= $end_day)
      )
GROUP BY 
    1, 2
ORDER BY 
    1 DESC, 
    2 ASC;
