# Financial Auditability Framework

The `loan_analyzer` package is built with a "Reconciliation First" philosophy. This document explains the mathematical and technical framework that ensures every principal change is auditable and justified.

---

## 1. The Accounting Identity

At the core of the system is the **Principal Reconciliation Identity**. For any given period, the change in principal must be fully explained by known financial events:

$$ \Delta Principal = Amortization + WriteOffs $$

Where:
- **$\Delta Principal$**: `Opening Principal - Closing Principal`
- **Amortization**: `MAX(Cash Received - Interest Accrued - Penalties, 0)`
- **WriteOffs**: Principal value explicitly forgiven or moved to a loss state.

If $( \Delta Principal ) - ( Amortization + WriteOffs ) \neq 0$, the system flags a **Reconciliation Gap**.

---

## 2. Audit SQL Schema

The `audit_loan.sql` script (orchestrated via `LoanAudit.audit_loan()`) exposes the following auditable columns:

| Column | Description | Type |
| :--- | :--- | :--- |
| `opening_principal` | The balance at the exact start of the month. | Double |
| `interest_accrued` | Interest generated during the month ($Balance \times Rate$). | Double |
| `cash_received` | Total cash inflow from the borrower. | Double |
| `penalty_occurred` | Penalties incurred (which consume cash before principal). | Double |
| `amortization` | The "Net Principal Paydown" after interest and penalties. | Double |
| `write_off_occurred` | Principal reduction due to write-off events. | Double |
| `closing_principal` | The balance after all events are processed. | Double |
| **`reconciliation_gap`** | **The proof of integrity. Must be 0.00.** | Double |
| **`computed_at`** | **Timestamp indicating exactly when the state was calculated.** | Timestamp |

---

## 3. How to Conduct an Audit

### Full Loan History Audit
To retrieve the entire history of a loan with all calculated statistics (including DPD and delinquency categories), use the `get_loan_audit` method:

```python
# Returns a DataFrame of the entire loan history
history = auditor.get_loan_audit("L001")

# Or get a specific month's data
jan_audit = auditor.get_loan_audit("L001", "2024-01-01")
```

The resulting data includes all `loan_state` columns joined with delinquency metrics from the `instalment_delinquency` table.

### Forensic Investigation
If a borrower disputes their balance, you can query the system for the exact state on a specific date in a human-readable format:

```python
from loan_analyzer import LoanAudit

# Investigating a specific loan
auditor = LoanAudit(calculator)
report = auditor.audit_loan("loan-uuid-123", "2024-01-01")
print(report)
```

### Interpreting the Reconciliation Gap
The `reconciliation_gap` is the most important field for an auditor.

- **Gap = 0.00**: The loan state is mathematically sound. The closing balance is perfectly explained by the inputs.
- **Gap > 0**: There is "Missing Principal". The balance dropped more than the payments and write-offs account for. This usually indicates a bug in the source `actual_payments` data or a manual adjustment not captured in the system.
- **Gap < 0**: There is "Ghost Principal". The balance is higher than it should be given the payments made.

---

### Automated Calculation Validation
Beyond individual loan investigation, the system includes a batch validator that runs invariant tests across the entire dataset after the balance engine has completed.

```python
auditor = LoanAudit(calculator)
passed, report = auditor.validate_calculations()
```
The `validate_calculations()` method executes tests in `src/loan_analyzer/core/tests/calculation_validation/` such as:
- `test_sum_reconciliation.sql`: Ensuring the sum of interest, principal, and penalties equals the total cash received globally.
- `test_global_principal_drift.sql`: Ensuring no principal is "lost" or "created" across all recursive steps.

---

## 4. Technical Implementation

The auditability is powered by two main SQL components:

1.  **`recursive_loan_state.sql`**: Located in `src/loan_analyzer/core/sql/`. This script acts as the "General Ledger". It processes transactions chronologically, ensuring that interest and penalties are satisfied before any principal is amortized.
2.  **`audit_loan.sql`**: Located in `src/loan_analyzer/core/sql/`. This script acts as the "Auditor". It pulls a specific slice from the ledger and performs the cross-check calculation in real-time.

By keeping these in SQL, we ensure that the audit logic is vectorized, high-performance, and easily verifiable by anyone with SQL knowledge, independent of the Python wrapper.
