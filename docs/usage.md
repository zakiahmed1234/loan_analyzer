# Usage Guide

This guide provides an in-depth look at the `loan_analyzer` package, its architecture, and how to use its core components to build auditable financial reports.

---

## 1. Data Ingestion: `DataLoader`

The `DataLoader` class is the entry point for all data operations. It manages a DuckDB session and handles the mapping of CSV files to relational tables.

### Initialization
```python
from loan_analyzer import DataLoader
import duckdb

# Recommended: Automatic in-memory connection
loader = DataLoader("path/to/csvs", output_format="csv")

# Advanced: Use an existing persistent DuckDB file
con = duckdb.connect("my_audit_database.db")
loader = DataLoader("path/to/csvs", connection=con, output_format="parquet")
```

### Behavior
Upon initialization, `DataLoader` automatically:
- Discovers all `.csv` files in the provided path.
- Creates DuckDB tables named after the filenames (e.g., `loans.csv` becomes the table `loans`).
- Uses DuckDB's `read_csv_auto` for intelligent schema detection.

---

## 2. Integrity Check: `DataValidation`

The `DataValidation` class executes the validation engine to ensure the input data follows financial invariants.

### Methods

#### `validate_all()`
Iterates through all `test_*.sql` files in the `src/loan_analyzer/core/tests/data_validation/` directory.
- **Returns**: A pandas DataFrame containing the results.
- **Built-in Checks**:
    - `test_uniqueness.sql`: No duplicate primary keys.
    - `test_principal_invariants.sql`: Principal never goes below zero or increases without cause.
    - `test_reconciliation.sql`: Payment components sum to the total payment.
    - `test_terminal_states.sql`: Loans marked as 'Paid Off' have a zero balance.
    - `test_cash_monotonicity.sql`: Total cash received never decreases.

```python
from loan_analyzer import DataValidation
validator = DataValidation(loader)
results_df = validator.validate_all()
```

---

## 3. Analytics Engine: `LoanCalculation`

The `LoanCalculation` implements the core financial logic using SQL transformations. It requires a `DataValidation` instance to ensure data quality before processing.

### Methods

#### `run_loan_state()`
Computes the recursive monthly state for every loan. This is the foundation for all other metrics.
- **Logic**: Uses a Recursive Common Table Expression (CTE) located in `src/loan_analyzer/core/sql/recursive_loan_state.sql`.
- **Columns in Output Table (`loan_state`)**:
    - `opening_principal`: Balance at start of month.
    - `interest_accrued`: Monthly interest based on the loan's rate.
    - `cash_received`: Total payments received in the period.
    - `amortization`: Portion of cash applied to principal.
    - `closing_principal`: Balance at end of month.
    - `computed_at`: Timestamp of when the record was generated.

#### `run_delinquency()`
Calculates the delinquency status for every scheduled repayment.
- **Logic**: Window functions calculate the "cumulative paid" vs "cumulative due" to find the exact date an instalment was satisfied.
- **Output Table**: `instalment_delinquency`
- **Categories**: `current`, `dpd 1-29`, `dpd 30-59`, `dpd 60-89`, `dpd 90+`, `paid off`, `written off`.
- **Metadata**: Includes a `computed_at` timestamp.

#### `run_all()`
Convenience method to run both `run_loan_state()` and `run_delinquency()` in sequence.

---

## 4. Multi-Dimensional Analytics: Metrics Runners

The system includes specialized runners for high-level analytics. Each runner follows a consistent interface.

### Available Runners
- **`RiskMetrics`**: Focuses on default rates, delinquency status distributions, and Loss Given Default (LGD).
- **`CreditMetrics`**: Analyzes credit profiles, score progression over time, and credit grade transitions.
- **`ImpactMetrics`**: Tracks the social impact, including loan use categories and borrower demographic shifts.
- **`PricingMetrics`**: Evaluates the yield curve, interest vintages, and pricing vs. risk correlations.

### Usage Pattern
```python
from loan_analyzer import RiskMetrics

# Initialize with the calculator (which holds the computed states)
risk_runner = RiskMetrics(calculator)

# Check available metrics in this category
print(risk_runner.registry)

# Run a specific metric and save to Hive-style directory
risk_runner.run_metric("defaults", output_base_dir="analytics", output_format="csv")
```

---

## 5. Forensic Investigation: `LoanAudit`

The `LoanAudit` class provides auditing tools for the calculated loan states.

### Methods

#### `audit_loan(loan_id, as_of_date)`
Provides a human-readable reconciliation report for a specific loan and date.
- **Objective**: To answer "Why did the principal change by X amount?"
- **Reconciliation Proof**:
    The method calculates a `reconciliation_gap`. 
    `Gap = (Opening - Closing) - (Amortization + Write-offs)`.
    A successful audit returns a gap of `0.00`.

#### `get_loan_audit(loan_id, period_start=None)`
Retrieves a detailed pandas DataFrame containing the full audited history or a specific month's data.
- **Data Joined**: Combines `loan_state` (financials) with `instalment_delinquency` (DPD, categories, payment flags).
- **Parameters**:
    - `loan_id`: The ID of the loan to audit.
    - `period_start` (Optional): ISO date string (e.g., `'2024-01-01'`) for a single month's audit.

```python
from loan_analyzer import LoanAudit
auditor = LoanAudit(calculator)

# 1. Full Audit History
history_df = auditor.get_loan_audit("LOAN-123")

# 2. Monthly Detailed Audit
jan_audit_df = auditor.get_loan_audit("LOAN-123", "2024-01-01")

# 3. Human-Readable Forensic Report
report = auditor.audit_loan("LOAN-123", "2023-12-01")
print(report)
```

---

## 6. Full Integration Example

```python
import os
from loan_analyzer import (
    DataLoader, 
    DataValidation, 
    LoanCalculation, 
    LoanAudit,
    RiskMetrics
)

def generate_monthly_report(data_folder, lender_id="LENDER_001", output_format="csv"):
    # 1. Load (Auto-loads CSVs and archives to Hive)
    loader = DataLoader(data_folder, lender_id=lender_id, output_format=output_format)
    
    # 2. Validate
    validator = DataValidation(loader)
    report = validator.validate_all()
    if not report.passed.all():
        failed_checks = report[report.passed == False].check_name.tolist()
        print(f"Integrity check failed: {failed_checks}")
        
    # 3. Compute
    calculator = LoanCalculation(validator, output_format=output_format)
    calculator.run_all()
    
    # 4. Forensic Audit for Verification
    auditor = LoanAudit(calculator)
    audit_passed, audit_report = auditor.validate_calculations()
    if audit_passed:
        print("✅ Calculation logic verified and reconciled.")
    
    # 5. Run Analytics
    risk_runner = RiskMetrics(calculator)
    risk_runner.run_metric("defaults", output_base_dir="analytics", output_format=output_format)

# Run for a specific batch
generate_monthly_report("FakeData/robust", "LENDER_GOLD_001", "csv")
```
