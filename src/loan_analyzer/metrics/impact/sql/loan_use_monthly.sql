SELECT
    DATE_TRUNC('month', CAST(origination_date AS DATE)) as disbursement_month,
    loan_use,
    -- Total capital for this specific use this month
    SUM(loan_amount) as monthly_amount,
    -- Number of loans for this use
    COUNT(loan_id) as loan_count,
    -- Percentage of the month's total capital (to see the shift in share)
    ROUND(
        100.0 * SUM(loan_amount) / SUM(SUM(loan_amount)) OVER (PARTITION BY DATE_TRUNC('month', CAST(origination_date AS DATE))),
        2
    ) as pct_of_monthly_volume
FROM loans
WHERE
    lender_id = $lender_id
    AND (
        year > $start_year OR
        (year = $start_year AND month > $start_month) OR
        (year = $start_year AND month = $start_month AND day >= $start_day)
    )
    AND (
        year < $end_year OR
        (year = $end_year AND month < $end_month) OR
        (year = $end_year AND month = $end_month AND day <= $end_day)
    )
GROUP BY 1, 2
ORDER BY 1 DESC, 2 DESC;
