import argparse
import sys
import os
from pathlib import Path

# Ensure src is in the path so we can import loan_analyzer
sys.path.append(str(Path(__file__).parent / "src"))

try:
    from loan_analyzer import DataLoader, DataValidation, LoanCalculation
except ImportError as e:
    print(f"Error: Could not import loan_analyzer components. {e}")
    sys.exit(1)

def run_pipeline(data_dir: str):
    """
    Orchestrates the loan analysis pipeline.
    """
    print(f"🚀 Starting Loan Analysis Pipeline for: {data_dir}")
    print("-" * 50)

    try:
        # 1. Load Data
        print("📥 Phase 1: Data Ingestion")
        loader = DataLoader(data_dir)
        
        # 2. Validate Data
        print("\n🔍 Phase 2: Data Validation")
        validator = DataValidation(loader)
        report = validator.validate_all()
        
        passed_all = all(report['passed'])
        if not passed_all:
            print("⚠️  Validation Issues Detected:")
            print(report[report['passed'] == False][['check_name', 'details']])
            print("\nProceeding with calculation (calculations will abort if critical invariants fail)...")
        else:
            print("✅ All validation checks passed.")

        # 3. Run Calculations
        print("\n📈 Phase 3: Financial Calculations")
        calculator = LoanCalculation(validator)
        calculator.run_all()
        
        # Summary of results
        con = loader.get_connection()
        loan_count = con.execute("SELECT count(*) FROM loans").fetchone()[0]
        state_count = con.execute("SELECT count(*) FROM loan_state").fetchone()[0]
        delinq_count = con.execute("SELECT count(*) FROM instalment_delinquency").fetchone()[0]
        
        print("\n" + "=" * 50)
        print("🏁 Pipeline Summary")
        print(f"Loans Processed: {loan_count}")
        print(f"Monthly States Generated: {state_count}")
        print(f"Delinquency Records: {delinq_count}")
        print("=" * 50)
        
    except Exception as e:
        print(f"\n❌ Pipeline failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Loan Analyzer Orchestrator")
    parser.add_argument("data_dir", help="Directory containing loan CSV files")
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.data_dir):
        print(f"Error: {args.data_dir} is not a valid directory.")
        sys.exit(1)
        
    run_pipeline(args.data_dir)
