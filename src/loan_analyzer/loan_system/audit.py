import duckdb
import pandas as pd
from pathlib import Path
from .calculation import LoanCalculation

class LoanAudit:
    """
    Performs post-calculation validation and provides auditing tools for loan states.
    """
    def __init__(self, calculation: LoanCalculation):
        self.calculation = calculation
        self.con = calculation.con
        self.tests_path = Path(__file__).parent.parent / "tests" / "calculation_validation"
        self.sql_path = Path(__file__).parent.parent / "sql"

    def validate_calculations(self):
        """
        Runs all SQL tests in the calculation_validation directory.
        """
        print("\n--- Running Post-Calculation Validations ---")
        test_files = sorted(self.tests_path.glob("test_*.sql"))
        all_passed = True
        results = []

        for sql_file in test_files:
            name = sql_file.stem
            with open(sql_file, 'r') as f:
                query = f.read()
            
            try:
                res = self.con.execute(query).fetchone()
                passed = res[0] == 0
                details = f"Violations: {res[0]}" if not passed else "Passed"
                results.append({"check_name": name, "passed": passed, "details": details})
                
                if not passed:
                    print(f"❌ {name}: {details}")
                    all_passed = False
                else:
                    print(f"✅ {name}: Passed")
            except Exception as e:
                print(f"⚠️ {name}: Error - {e}")
                all_passed = False
        
        return all_passed, pd.DataFrame(results)

    def audit_loan(self, loan_id: str, as_of_date: str):
        """
        Provides a human-readable reconciliation for a specific loan and date.
        """
        sql_file = self.sql_path / "audit_loan.sql"
        with open(sql_file, 'r') as f:
            query = f.read()
        
        try:
            # The query expects [loan_id, as_of_date]
            res = self.con.execute(query, [loan_id, as_of_date]).df()
            
            if res.empty:
                return f"No records found for Loan ID {loan_id} on or before {as_of_date}."

            row = res.iloc[0]
            
            report = [
                f"--- Forensic Audit Report: {loan_id} (As of {as_of_date}) ---",
                f"Period Start:      {row['period_start']}",
                f"Opening Principal: {row['opening_principal']:.2f}",
                f"Closing Principal: {row['closing_principal']:.2f}",
                f"-------------------------------------------",
                f"Principal Change:  {row['actual_principal_change']:.2f} (Decrease)",
                f"Explained By:",
                f"  - Amortization:    {row['amortization']:.2f}",
                f"  - Write-offs:      {row['write_off_occurred']:.2f}",
                f"Total Reasoned:    {row['reasoned_principal_change']:.2f}",
                f"-------------------------------------------",
                f"Reconciliation Gap: {row['reconciliation_gap']:.2f}",
                f"Status:            {'✅ RECONCILED' if abs(row['reconciliation_gap']) < 0.01 else '❌ DISCREPANCY FOUND'}"
            ]
            
            # Additional metadata
            report.append(f"\nMetadata: Interest Accrued: {row['interest_accrued']:.2f}, Cash Received: {row['cash_received']:.2f}")
            
            return "\n".join(report)

        except Exception as e:
            return f"Error performing audit: {e}"

    def get_loan_audit(self, loan_id: str, period_start: str = None):
        """
        Retrieves full history or a specific month's audit data for a loan.
        Includes all stats from loan_state and delinquency metrics.
        """
        query = """
        SELECT 
            ls.*,
            id.days_past_due,
            id.dpd_category,
            id.scheduled_instalment_date,
            id.real_payment_date,
            id.flag_write_off_this_month,
            id.flag_prepayment_this_month
        FROM loan_state ls
        LEFT JOIN instalment_delinquency id 
            ON ls.loan_id = id.loan_id 
            AND date_trunc('month', CAST(ls.period_start AS DATE)) = date_trunc('month', CAST(id.scheduled_instalment_date AS DATE))
        WHERE ls.loan_id = ?
        """
        params = [loan_id]
        
        if period_start:
            query += " AND ls.period_start = ?"
            params.append(period_start)
            
        query += " ORDER BY ls.period_start ASC"
        
        return self.con.execute(query, params).df()
