SELECT COUNT(*)
FROM (
    SELECT 
        l.loan_id, 
        l.loan_amount - SUM(COALESCE(ap.actual_principal, 0)) as balance
    FROM loans l
    LEFT JOIN actual_payments ap ON l.loan_id = ap.loan_id
    GROUP BY l.loan_id, l.loan_amount
) WHERE balance < -0.01;