-- audit_loan.sql
-- Provides a detailed reconciliation of principal changes for a specific loan and date.
-- Use with parameters: [loan_id, as_of_date]

SELECT 
    loan_id,
    period_start,
    opening_principal,
    interest_accrued,
    cash_received,
    penalty_occurred,
    write_off_occurred,
    amortization,
    closing_principal,
    ROUND(opening_principal - closing_principal, 2) AS actual_principal_change,
    ROUND(amortization + write_off_occurred, 2) AS reasoned_principal_change,
    ROUND((opening_principal - closing_principal) - (amortization + write_off_occurred), 2) AS reconciliation_gap
FROM loan_state
WHERE loan_id = ? 
  AND period_start <= ?
ORDER BY period_start DESC
LIMIT 1;
