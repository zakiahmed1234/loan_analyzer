-- Test: Reconciliation
SELECT 
    payment_id,
    loan_id,
    actual_total_amount,
    (actual_principal + actual_interest + actual_fees + actual_vat + penalty_amount) as calculated_total,
    ABS(actual_total_amount - (actual_principal + actual_interest + actual_fees + actual_vat + penalty_amount)) as discrepancy
FROM actual_payments
WHERE ABS(actual_total_amount - (actual_principal + actual_interest + actual_fees + actual_vat + penalty_amount)) > 0.05;
