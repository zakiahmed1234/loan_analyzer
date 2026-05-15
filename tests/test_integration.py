import pytest
import os
import sys
from pathlib import Path

# Add src to sys.path to import the package
sys.path.append(str(Path(__file__).parent.parent / "src"))

from loan_analyzer import DataLoader, DataValidation, LoanCalculation, LoanAudit

@pytest.fixture
def sample_data_dir():
    return str(Path(__file__).parent / "sample_data")

def test_full_pipeline(sample_data_dir):
    # 1. DataLoader
    loader = DataLoader(sample_data_dir)
    
    # Verify tables loaded
    tables = loader.con.execute("SHOW TABLES").fetchall()
    table_names = [t[0] for t in tables]
    assert "loans" in table_names
    assert "actual_payments" in table_names
    assert "borrowers" in table_names
    assert "scheduled_repayments" in table_names
    
    # 2. DataValidation
    validator = DataValidation(loader)
    report = validator.validate_all()
    assert report is not None
    assert (report['passed'] == True).all(), f"Validation failed: {report[report['passed'] == False]}"
    
    # 3. LoanCalculation
    calculator = LoanCalculation(validator)
    calculator.run_loan_state()
    
    # Verify loan_state table exists and has data
    state_count = loader.con.execute("SELECT count(*) FROM loan_state").fetchone()[0]
    assert state_count > 0
    
    calculator.run_delinquency()
    # Verify instalment_delinquency table exists and has data
    del_count = loader.con.execute("SELECT count(*) FROM instalment_delinquency").fetchone()[0]
    assert del_count > 0
    
    # 4. LoanAudit
    auditor = LoanAudit(calculator)
    # Check L001 for Feb 2024
    audit_report = auditor.audit_loan("L001", "2024-02-01")
    assert "L001" in audit_report
    assert "RECONCILED" in audit_report
    
    # 5. Verify calculation results for L001
    # Opening: 1000. Interest: 1000 * (12/1200) = 10. Cash: 200. Amort: 200 - 10 = 190. Closing: 1000 - 190 = 810.
    res = loader.con.execute("SELECT closing_principal FROM loan_state WHERE loan_id = 'L001' AND period_number = 2").fetchone()
    assert abs(res[0] - 810.0) < 0.01

def test_audit_calculation_validation(sample_data_dir):
    loader = DataLoader(sample_data_dir)
    validator = DataValidation(loader)
    calculator = LoanCalculation(validator)
    calculator.run_all()
    
    auditor = LoanAudit(calculator)
    passed, results = auditor.validate_calculations()
    assert passed, f"Calculation validation failed: {results}"
