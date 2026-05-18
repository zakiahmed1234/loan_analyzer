import duckdb
from pathlib import Path
from .validation import DataValidation
from ...utils.hive_saver import save_hive_partitioned

class LoanCalculation:
    """
    Executes financial calculations and metrics after ensuring data validity.
    """
    def __init__(self, validator: DataValidation, output_format: str = "csv"):
        self.validator = validator
        self.con = validator.con
        self.sql_path = Path(__file__).parent / ".." / "sql"
        self.lender_id = validator.loader.lender_id
        self.output_base_dir = getattr(validator.loader, 'output_base_dir', '.')
        self.output_format = output_format

    def _ensure_validated(self):
        """
        Checks if validation has been run and passed.
        """
        # Check if validation_results table exists and has results
        table_exists = self.con.execute(
            "SELECT count(*) FROM information_schema.tables WHERE table_name = 'validation_results'"
        ).fetchone()[0] > 0

        if not table_exists:
            print("Validation not found. Running auto-validation...")
            self.validator.validate_all()
        
        # Check for any failures
        failures = self.con.execute("SELECT check_name FROM validation_results WHERE passed = FALSE").fetchall()
        if failures:
            fail_names = [f[0] for f in failures]
            raise ValueError(f"Data validation failed for invariants: {fail_names}. Calculations aborted.")

    def run_loan_state(self):
        """
        Executes the recursive loan state calculation.
        """
        self._ensure_validated()
        
        sql_file = self.sql_path / "recursive_loan_state.sql"
        with open(sql_file, 'r') as f:
            query = f.read()
        
        try:
            print("Calculating recursive loan state...")
            self.con.execute(query)
            print("✅ Loan state calculated successfully.")
            
            # Save to Hive
            df = self.con.execute("SELECT * FROM loan_state").df()
            save_hive_partitioned(
                df=df,
                base_dir=self.output_base_dir,
                category="core_computations",
                item_name="loan_state",
                lender_id=self.lender_id,
                output_format=self.output_format
            )
        except Exception as e:
            raise RuntimeError(f"Failed to calculate loan state: {e}")

    def run_delinquency(self):
        """
        Executes the delinquency waterfall calculation.
        """
        self._ensure_validated()
        
        sql_file = self.sql_path / "instalment_delinquency_maker.sql"
        with open(sql_file, 'r') as f:
            query = f.read()
            
        try:
            print("Calculating delinquency metrics...")
            # Note: The SQL file typically creates a table or view
            clean_query = query.strip().rstrip(';')
            self.con.execute(f"CREATE OR REPLACE TABLE instalment_delinquency AS SELECT *, CURRENT_TIMESTAMP AS computed_at FROM ({clean_query})")
            print("✅ Delinquency metrics calculated successfully.")
            
            # Save to Hive
            df = self.con.execute("SELECT * FROM instalment_delinquency").df()
            save_hive_partitioned(
                df=df,
                base_dir=self.output_base_dir,
                category="core_computations",
                item_name="instalment_delinquency",
                lender_id=self.lender_id,
                output_format=self.output_format
            )
        except Exception as e:
            raise RuntimeError(f"Failed to calculate delinquency: {e}")

    def run_all(self):
        """
        Runs the full calculation pipeline.
        """
        self.run_loan_state()
        self.run_delinquency()
        print("\n--- Full Calculation Pipeline Complete ---")
