# Usage Guide

## Core Components

### LoanDataLoader
The `LoanDataLoader` is responsible for reading CSV files and verifying data integrity.

```python
from loan_analyzer import LoanDataLoader

loader = LoanDataLoader("FakeData/1")
loader.load_data()

# Runs the internal SQL validation suite
success, errors = loader.validate()
if not success:
    print(f"Data issues found: {errors}")
```

### LoanMetricsRunner
The `LoanMetricsRunner` uses the data loaded into DuckDB to compute analytical tables.

```python
from loan_analyzer import LoanMetricsRunner

runner = LoanMetricsRunner(loader)

# Computes monthly principal/interest state
runner.run_loan_state(output_path="loan_state.csv")

# Computes delinquency buckets and DPD
runner.run_delinquency(output_path="delinquency.csv")
```

## Validation Tests Included
1. **Uniqueness**: Ensures IDs are unique.
2. **Reconciliation**: Checks `total_amount` against components.
3. **Principal Invariants**: Flags negative or increasing principal.
4. **Terminal States**: Validates `PaidOff` status consistency.
5. **Monotonicity**: Checks chronological consistency.

## Customizing Tests
You can provide a custom directory of SQL files to the `validate` method:
```python
loader.validate(tests_dir="my_custom_sql_tests/")
```
