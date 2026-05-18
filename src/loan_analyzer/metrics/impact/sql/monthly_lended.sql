SELECT
    DATE_TRUNC('month', CAST(origination_date AS DATE)) as disbursement_month,
    -- The "Derivative": Total capital out the door this month
    SUM(loan_amount) as monthly_disbursed_amount,
    -- The Cumulative: Total capital ever lent by the platform
    SUM(SUM(loan_amount)) OVER (ORDER BY DATE_TRUNC('month', CAST(origination_date AS DATE)) ASC) as cumulative_disbursed_amount,
    -- Context: How many individual loans made up this amount?
    COUNT(loan_id) as loan_count,
    -- Metric: Average loan size (Are we lending bigger or smaller amounts?)
    ROUND(AVG(loan_amount), 2) as avg_loan_size
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
GROUP BY 1
ORDER BY disbursement_month DESC;
