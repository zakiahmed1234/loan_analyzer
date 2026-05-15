SELECT COUNT(*) FROM (
    SELECT 
        l.loan_id,
        l.loan_status,
        l.loan_amount,
        SUM(ap.actual_principal + ap.write_off_amount) as total_reduction
    FROM loans l
    LEFT JOIN actual_payments ap ON l.loan_id = ap.loan_id
    WHERE l.loan_status = 'PaidOff'
    GROUP BY l.loan_id, l.loan_status, l.loan_amount
    HAVING ABS(l.loan_amount - SUM(ap.actual_principal + ap.write_off_amount)) > 0.1
);