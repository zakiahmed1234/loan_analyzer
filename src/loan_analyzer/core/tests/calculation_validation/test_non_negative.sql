-- test_non_negative.sql
-- Checks if closing principal is ever negative
SELECT COUNT(*) FROM loan_state WHERE closing_principal < -0.01;
