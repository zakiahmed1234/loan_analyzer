# Loan Analyzer

A SQL-based loan history machine, with correctness enforced via SQL-defined invariants.
![Demo](workflow.gif)
![Walkthrough](demo.ipynb)

## Introduction
### Problem
Accurately modelling a loan's full history is essential to understanding its future. A single missed payment may seem alarming in isolation, but observing the borrower's prior behaviour - such as repeated delays due to late salary payments - provides human context that a snapshot view can't capture. Further, complete histories are also critical for compliance and auditability, ensuring that every payment and balance can be reconstructed and verified, and for cohort level analyses, enabling comparisons of regions or borrower segments.

### Difficulties

Scheduled loan payments are often just modelled as fixed payments at the start of each month. However, real world cashflows are irregular: borrowers may overpay, underpay, or pay late. Defining when a payment is "complete" requires rules for partial, early, or late payments, and handling these consistently is non-trivial.

This problem is made worse because although loans are paid as a fixed amount every month, this is split between a principal and an interest payment. The size of the interest payment depends on how much principal is left. At the beginning of your loan most of your money is going towards interest payments, whereas at the end you are mostly paying off your principal. This requires performing complex recursive calculations month on month.

Further, data is often missing, unordered, or doesn't add up correctly, providing further problems.

## Implementation

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
