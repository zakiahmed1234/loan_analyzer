# Loan Analyzer

A lightweight, SQL-powered engine for validating loan data and computing analytical metrics using DuckDB.

## Features

- **Schema & Invariant Validation**: Built-in SQL tests for uniqueness, reconciliation, principal tracking, and more.
- **Recursive State Engine**: Tracks monthly loan balances and interest accruals.
- **Delinquency Waterfall**: Computes Days Past Due (DPD) and classifies loans into delinquency buckets.
- **DuckDB Powered**: High-performance vectorized execution on local CSV files.

## Installation

You can install the package directly from GitHub:

```bash
pip install git+https://github.com/zakiahmed1234/loan_analyzer.git
```

## Quick Start

```python
from loan_analyzer import LoanDataLoader, LoanMetricsRunner

# 1. Load and Validate Data
loader = LoanDataLoader("path/to/your/csv_data")
loader.load_data()
is_valid, report = loader.validate()

# 2. Run Metrics
metrics = LoanMetricsRunner(loader)
metrics.run_loan_state()
metrics.run_delinquency()
```

## SQL Resources

The package includes internal SQL resources located in:
- `src/loan_analyzer/sql/`: Core metrics logic.
- `src/loan_analyzer/tests/`: Validation tests.

## License

MIT
