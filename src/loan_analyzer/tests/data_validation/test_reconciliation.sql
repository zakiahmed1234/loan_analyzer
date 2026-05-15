SELECT COUNT(*) FROM (
    SELECT 
        payment_id,
        loan_id,
        actual_total_amount,
        (actual_principal + actual_interest + actual_fees + penalty_amount) as calculated_total
    FROM actual_payments
    WHERE ABS(actual_total_amount - (actual_principal + actual_interest + actual_fees + penalty_amount)) > 0.05
);