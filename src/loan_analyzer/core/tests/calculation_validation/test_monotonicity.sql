-- test_monotonicity.sql
-- Checks if principal is monotonically decreasing (closing <= opening)
SELECT COUNT(*) FROM loan_state WHERE closing_principal > opening_principal + 0.01;
