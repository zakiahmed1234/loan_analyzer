-- Test: ID Uniqueness
SELECT 'loans' as table_name, 'loan_id' as column_name, COUNT(*) - COUNT(DISTINCT loan_id) as duplicate_count
FROM loans
HAVING COUNT(*) - COUNT(DISTINCT loan_id) > 0

UNION ALL

SELECT 'actual_payments', 'payment_id', COUNT(*) - COUNT(DISTINCT payment_id)
FROM actual_payments
HAVING COUNT(*) - COUNT(DISTINCT payment_id) > 0

UNION ALL

SELECT 'borrowers', 'borrower_id', COUNT(*) - COUNT(DISTINCT borrower_id)
FROM borrowers
HAVING COUNT(*) - COUNT(DISTINCT borrower_id) > 0;
