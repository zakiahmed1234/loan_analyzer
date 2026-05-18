/*
In this, we track the evolution of average credit bureau score and internal score for new loan originations over time. We take an average of the scores of all of the loans originating in each month, and then record it in order to see if the scores are improving.
*/

SELECT
    DATE_TRUNC('month', CAST(origination_date AS DATE)) as origination_month,
    -- Count of loans to ensure the average is based on a solid sample size
    COUNT(loan_id) as total_loans,
    -- Average External Score (Credit Bureau)
    ROUND(AVG(credit_bureau_score), 2) as avg_external_score,
    -- Average Internal Score (Your proprietary scoring)
    ROUND(AVG(internal_score), 2) as avg_internal_score,
    -- Optional: The gap between internal and external
    -- (Helps identify if your internal scoring is more "generous" than bureaus)
    ROUND(AVG(internal_score - credit_bureau_score), 2) as score_variance
FROM loans
-- Ensuring we only average records that actually have scores
WHERE credit_bureau_score IS NOT NULL
  AND internal_score IS NOT NULL
  AND lender_id = ${lender_id}
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
ORDER BY 1 DESC;
