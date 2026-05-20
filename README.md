# Loan Analyzer

A SQL-based financial state machine for reconstructing time-series loan histories using recursive amortization, with correctness enforced via SQL-defined invariants.
![Demo](workflow.gif)
![Walkthrough](demo.ipynb)

## Features

- Recursive amortization engine using SQL CTEs
- Deterministic balance reconstruction
- Financial invariant validation
- Loan audit reconciliation
- Portfolio risk and yield metrics
- Warehouse-compatible SQL execution

---

## Installation

The package can be installed directly from GitHub:

```bash
pip install git+https://github.com/zakiahmed1234/loan_analyzer.git
```

---

## Quick Start

Use ```synthetic-data``` in the repo for testing.

```python
from loan_analyzer import DataLoader, DataValidation, LoanCalculation, LoanAudit, CreditMetrics

# 1. Load data from the included synthetic dataset
loader = DataLoader("sample_data/perfect")
validator = DataValidation(loader)

# 2. Run recursive amortization engine
calculator = LoanCalculation(validator)
calculator.run_all()

# 3. Forensic Audit: Re-audit a specific loan to reconcile balance
auditor = LoanAudit(calculator)
print(auditor.audit_loan("LOAN_001", "2023-12-01"))

# 4. Analytics: Generate Vintage DPD (Days Past Due) curve
credit = CreditMetrics(calculator)
df_dpd = credit.run_metric("vintage_delinquency")
fig_json = credit.get_graph("vintage_delinquency", df_dpd)
```

---

### Codebase Structure

```text
loan_analyzer/
├── src/
│   └── loan_analyzer/
│       ├── core/
│       │   ├── loan_system/    # Core Python logic (DataLoader, calculation, etc.)
│       │   ├── sql/            # Core SQL transformations (recursive CTEs)
│       │   └── tests/          # Data validation and invariant tests
│       ├── metrics/            # Multi-dimensional analytics modules
│       ├── utils/              # Helper utilities (Hive archiving)
│       └── __init__.py
├── docs/                       # Detailed documentation guides
├── demo.ipynb                  # End-to-end Jupyter walkthrough
├── workflow.gif                # Pipeline execution animation
├── pyproject.toml              # Build configuration
└── README.md
```

---
## Invariants

The system enforces deterministic financial consistency before and after loan reconstruction.

### Input Checks

- Unique identifiers across loans, borrowers, and payments
- Schema and datatype validation
- Reconciled payment cash flows
- Irreversible terminal states (`paid_off`, `defaulted`, `written_off`)
- Monotonic cumulative cash payments
- Nonnegative balances and accruals
- Chronologically valid payment timelines

### Output Checks

- Continuous balance roll-forward between periods
- Nonnegative principal and accrued balances
- Monotonic principal reduction when no penalties or capitalizations apply

---
## Infrastructure

- Apache Hive-backed Parquet tables are used for data storage to support downstream auditability.  
- SQL transformations are executed through a dialect-agnostic query layer to ensure compatibility across analytical warehouses, including AWS Athena and BigQuery.

---

## Metrics

The system provides 21 analytical metrics across four categories:

- risk  
- yield  
- pricing  
- borrower impact  

Selected metrics include time-series visualizations and distributional summaries to support downstream portfolio analysis and monitoring.
