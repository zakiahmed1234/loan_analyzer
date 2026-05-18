import argparse
import sys
import os
from pathlib import Path

# Ensure src is in the path so we can import loan_analyzer
sys.path.insert(0, str(Path(__file__).parent / "src"))

try:
    from loan_analyzer import (
        DataLoader, 
        DataValidation, 
        LoanCalculation, 
        LoanAudit,
        RiskMetrics,
        ImpactMetrics,
        CreditMetrics,
        PricingMetrics
    )
except ImportError as e:
    print(f"Error: Could not import loan_analyzer components. {e}")
    sys.exit(1)

def run_pipeline(data_dir: str, lender_id: str = None, output_dir: str = "analytics", output_format: str = "csv"):
    """
    Orchestrates the full loan analysis expo.
    """
    print(f"\n{'='*60}")
    print(f"🚀 LOAN ANALYZER FULL EXPO")
    print(f"{'='*60}")
    print(f"Target Directory: {data_dir}")
    print(f"Lender ID:        {lender_id or 'Auto-generated'}")
    print(f"Output Directory: {output_dir}")
    print(f"Output Format:    {output_format}")
    print("-" * 60)

    try:
        # 1. Load Data
        print("\n📥 PHASE 1: DATA INGESTION & HIVE ARCHIVING")
        loader = DataLoader(data_dir, lender_id=lender_id, output_base_dir=".", output_format=output_format)
        
        # 2. Validate Data
        print("\n🔍 PHASE 2: DATA VALIDATION (INVARIANTS)")
        validator = DataValidation(loader)
        report = validator.validate_all()
        
        passed_all = all(report['passed'])
        if not passed_all:
            print("⚠️  Validation Issues Detected:")
            print(report[report['passed'] == False][['check_name', 'details']])
        else:
            print("✅ All data integrity checks passed.")

        # 3. Run Core Calculations
        print("\n📈 PHASE 3: CORE FINANCIAL CALCULATIONS")
        calculator = LoanCalculation(validator, output_format=output_format)
        calculator.run_all()
        
        # 4. Post-Calculation Audit
        print("\n🕵️  PHASE 4: POST-CALCULATION AUDIT")
        auditor = LoanAudit(calculator)
        audit_passed, audit_report = auditor.validate_calculations()
        if not audit_passed:
            print("❌ Discrepancies found in calculations!")
        else:
            print("✅ Calculation logic verified and reconciled.")

        # 5. Metrics & Analytics
        print("\n📊 PHASE 5: MULTI-DIMENSIONAL ANALYTICS (HIVE OUTPUT)")
        
        categories = [
            (RiskMetrics, "Risk"),
            (CreditMetrics, "Credit"),
            (ImpactMetrics, "Impact"),
            (PricingMetrics, "Pricing")
        ]
        
        for metric_class, name in categories:
            print(f"\n--- Running {name} Metrics ---")
            runner = metric_class(calculator)
            registry = runner.registry
            for metric_name in registry:
                print(f"  Calculating {metric_name}...")
                runner.run_metric(metric_name, output_base_dir=output_dir, output_format=output_format)
        
        # 6. Final Summary
        con = loader.get_connection()
        loan_count = con.execute("SELECT count(*) FROM loans").fetchone()[0]
        state_count = con.execute("SELECT count(*) FROM loan_state").fetchone()[0]
        
        print(f"\n{'='*60}")
        print("🏁 EXPO COMPLETE")
        print(f"{'='*60}")
        print(f"Total Loans Processed:    {loan_count}")
        print(f"Monthly States Archived:  {state_count}")
        print(f"Audit Status:             {'✅ CLEAN' if audit_passed else '❌ FAILED'}")
        print(f"Hive Outputs:             ./raw_inputs, ./core_computations, ./{output_dir}")
        print(f"{'='*60}\n")
        
    except Exception as e:
        print(f"\n❌ Pipeline failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Loan Analyzer Full Expo")
    parser.add_argument("data_dir", nargs="?", default="FakeData/robust", help="Directory containing loan CSV files")
    parser.add_argument("--lender-id", default="LENDER_GOLD_001", help="Lender identifier")
    parser.add_argument("--output", default="analytics", help="Output directory for metrics")
    parser.add_argument("--format", default="csv", choices=["csv", "parquet"], help="Output format (default: csv)")
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.data_dir):
        print(f"Error: {args.data_dir} is not a valid directory.")
        # Try to generate it if it's the default
        if args.data_dir == "FakeData/robust":
            print("Default data not found. Please run generate_data.py first.")
        sys.exit(1)
        
    run_pipeline(args.data_dir, args.lender_id, args.output, args.format)
