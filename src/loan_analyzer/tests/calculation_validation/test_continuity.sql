-- test_continuity.sql
-- Checks if opening principal at t+1 equals closing principal at t
SELECT COUNT(*) FROM (
    SELECT 
        loan_id,
        period_start,
        opening_principal,
        LAG(closing_principal) OVER (PARTITION BY loan_id ORDER BY period_start) as prev_closing
    FROM loan_state
) WHERE prev_closing IS NOT NULL AND ABS(opening_principal - prev_closing) > 0.01;
