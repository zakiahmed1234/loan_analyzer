/* We calculate trends of the distribution of loan grade assigned to new loans over time. Specifically, for each month, we look at all the loans that originated. Then, we record the distribution of loan grades for that month, and then vary over all months. */

SELECT
    DATE_TRUNC('month', CAST(origination_date AS DATE)) as origination_month,
    loan_grade,
    -- Count of loans for this grade in this month
    COUNT(loan_id) as loan_count,
    -- Total capital volume for this grade
    SUM(loan_amount) as total_amount,
    -- The % Distribution (Percentage of this month's loans that fell into this grade)
    ROUND(
        100.0 * COUNT(loan_id) / SUM(COUNT(loan_id)) OVER (PARTITION BY DATE_TRUNC('month', CAST(origination_date AS DATE))),
        2
    ) as pct_of_monthly_count
FROM loans
WHERE
    lender_id = ${lender_id}
    AND loan_grade IS NOT NULL
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
GROUP BY 1, 2
ORDER BY 1 DESC, 2 ASC;
