-- Test: DPD & Payment Monotonicity
SELECT 'payment_before_origination' as issue_type, ap.payment_id, ap.loan_id
FROM actual_payments ap
JOIN loans l ON ap.loan_id = l.loan_id
WHERE CAST(ap.actual_payment_date AS DATE) < CAST(l.origination_date AS DATE)

UNION ALL

SELECT 'negative_payment_amount', payment_id, loan_id
FROM actual_payments
WHERE actual_total_amount < 0;
