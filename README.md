# Loan Analyzer

A lightweight, SQL-powered engine for validating loan data and computing delinquency metrics using DuckDB. It is designed to transform raw CSV loan data into auditable, time-series financial states. The engine takes in 

    - Borrower data
    - Loan data
    - collateral data
    - colateral valuation data
    - Scheduled payment data
    - Actual payment data

and calculates how the amount owed over time changes for each loan via complex amortization calculations.

## Project Structure

The project follows a structured layout for modularity and scalability:

```text
loan_analyzer/
├── src/
│   └── loan_analyzer/
│       ├── core/
│       │   ├── loan_system/    # Core Python logic (DataLoader, Calculation, etc.)
│       │   ├── sql/            # Core SQL transformations (Recursive CTEs)
│       │   └── tests/          # Data validation invariant tests
│       ├── metrics/            # Multi-dimensional analytics modules
│       │   ├── risk/           # Default rates, delinquency status
│       │   ├── credit/         # Credit profiles, transitions
│       │   ├── impact/         # Borrower delta, loan use
│       │   └── pricing/        # Yield curves, fee yields
│       └── utils/              # Helper utilities (Hive archiving)
├── docs/                       # Documentation
├── sqlmetricsnew/              # Experimental/New SQL metrics
├── pyproject.toml              # Build configuration
└── README.md
```

## Installation

You can install the package directly from GitHub:

```bash
pip install git+https://github.com/zakiahmed1234/loan_analyzer.git
```

---

## Core Package Reference

The package is modularized into specialized classes within the `loan_analyzer` package.

### 1. `DataLoader`
Handles data ingestion from CSVs into an in-memory DuckDB instance and manages Hive-style partitioning for raw inputs.

#### `__init__(directory_path, lender_id=None, connection=None, output_base_dir=None, output_format="csv")`
- **directory_path**: Directory containing the required CSV files.
- **lender_id**: Identifier for the lender (used for Hive partitioning).
- **connection**: (Optional) An existing DuckDB connection.
- **output_base_dir**: (Optional) Base directory for Hive archiving.
- **output_format**: (Optional) 'csv' or 'parquet' (default: 'csv').

---

### 2. `DataValidation`
Runs a suite of SQL-based invariant tests to ensure data integrity.

#### `validate_all()`
Runs all tests in `src/loan_analyzer/core/tests/data_validation/`.
- **Returns**: A pandas DataFrame containing the results.

---

### 3. `LoanCalculation`
The execution engine for financial business logic.

#### `run_all()`
Executes both `run_loan_state()` (Recursive Balance Engine) and `run_delinquency()` (Delinquency Waterfall).

---

### 4. `Multi-Dimensional Analytics`
Specialized runners for various financial metrics. Each runner manages a registry of SQL-based metrics.

- **`RiskMetrics`**: Defaults, LGD, DPD status distribution.
- **`CreditMetrics`**: Credit profiles, score progression, vintage delinquency.
- **`ImpactMetrics`**: Borrower delta, loan use, geographic distribution.
- **`PricingMetrics`**: Yield curves, interest vintage, pricing risk.

---

### 5. `LoanAudit`
The **Forensic Audit Tool**. Provides a line-item reconciliation of a loan's principal change and validates calculation logic.

---

## Advanced Usage Example

```python
from loan_analyzer import (
    DataLoader, 
    DataValidation, 
    LoanCalculation, 
    LoanAudit,
    RiskMetrics,
    ImpactMetrics
)

# 1. Setup Data Environment
loader = DataLoader("FakeData/robust", lender_id="LENDER_001")

# 2. Perform Health Check
validator = DataValidation(loader)
report = validator.validate_all()

# 3. Generate Financial Models
calculator = LoanCalculation(validator, output_format="csv")
calculator.run_all()

# 4. Forensic Investigation & Validation
auditor = LoanAudit(calculator)
audit_passed, audit_report = auditor.validate_calculations()
print(auditor.audit_loan("loan-uuid-123", "2024-01-01"))

# 5. Run Analytics
risk_runner = RiskMetrics(calculator)
risk_runner.run_metric("defaults", output_base_dir="analytics")
```

## CLI Usage

You can run the full pipeline using `main.py`:

```bash
# Defaults to CSV output
python main.py FakeData/robust --lender-id LENDER_GOLD_001 --output analytics

# Specify Parquet output
python main.py FakeData/robust --format parquet
```

## SQL Resources
The core logic is modularized in `src/loan_analyzer/core/sql/`. You can find the recursive CTEs for balance tracking and the cumulative window functions for delinquency there.

## License
MIT
