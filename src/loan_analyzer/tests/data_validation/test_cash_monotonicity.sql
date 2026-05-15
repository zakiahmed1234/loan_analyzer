WITH cumulative_cash AS (
    SELECT 
        loan_id, 
        actual_payment_date,
        SUM(actual_total_amount) OVER (PARTITION BY loan_id ORDER BY actual_payment_date) as running_total
    FROM actual_payments
),
diffs AS (
    SELECT 
        loan_id,
        running_total,
        LAG(running_total) OVER (PARTITION BY loan_id ORDER BY actual_payment_date) as prev_total
    FROM cumulative_cash
)
SELECT COUNT(*) FROM diffs WHERE running_total < prev_total;