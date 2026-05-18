SELECT
    DATE_TRUNC('month', CAST(l.origination_date AS DATE)) as approval_month,
    b.location_country,
    b.location_state_province,
    -- The "Volume" (Count of loans approved)
    COUNT(l.loan_id) as loans_approved,
    -- The "Capital Flow" (Sum of money lent)
    SUM(l.loan_amount) as total_amount_approved,
    -- Average loan size for this specific region
    ROUND(AVG(l.loan_amount), 2) as avg_loan_size_in_region
FROM loans l
JOIN borrowers b ON l.borrower_id = b.borrower_id
WHERE
    l.lender_id = ${lender_id}
    AND b.lender_id = ${lender_id}
    AND (
        l.year > ${start_year} OR
        (l.year = ${start_year} AND l.month > ${start_month}) OR
        (l.year = ${start_year} AND l.month = ${start_month} AND l.day >= ${start_day})
    )
    AND (
        l.year < ${end_year} OR
        (l.year = ${end_year} AND l.month < ${end_month}) OR
        (l.year = ${end_year} AND l.month = ${end_month} AND l.day <= ${end_day})
    )
-- We only look at 'Approved' or 'Disbursed' loans to ensure we're measuring actual impact
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2 DESC;
