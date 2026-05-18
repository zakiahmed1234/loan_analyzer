/* In this we record the interest rate of loans that originated in each period.*/

SELECT 
    DATE_TRUNC('month', CAST(origination_date AS DATE)) AS origination_month,
    loan_id,
    interest_rate
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
ORDER BY 
    1 DESC, 
    3 DESC;
