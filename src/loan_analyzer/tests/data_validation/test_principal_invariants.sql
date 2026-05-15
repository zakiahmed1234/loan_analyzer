-- Test: Principal Invariants
WITH payment_history AS (
    SELECT 
        ap.loan_id,
        CAST(ap.actual_payment_date AS DATE) as actual_payment_date,
        ap.payment_id,
        l.loan_amount as initial_principal,
        SUM(ap.actual_principal + ap.write_off_amount) OVER (PARTITION BY ap.loan_id ORDER BY ap.actual_payment_date, ap.payment_id) as cumulative_reduction
    FROM actual_payments ap
    JOIN loans l ON ap.loan_id = l.loan_id
),
principal_tracking AS (
    SELECT 
        *,
        (initial_principal - cumulative_reduction) as remaining_principal
    FROM payment_history
)
SELECT *
FROM principal_tracking
WHERE remaining_principal < -0.05;
