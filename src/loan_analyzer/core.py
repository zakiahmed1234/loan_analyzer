import duckdb
import os
import glob
import pandas as pd
from pathlib import Path

class LoanDataLoader:
    """
    Handles data ingestion and validation for loan datasets.
    """
    def __init__(self, data_path, con=None):
        self.data_path = data_path
        self.con = con or duckdb.connect(database=':memory:')
        self.tables = []

    def load_data(self):
        """Loads all CSV files from the data path into DuckDB."""
        csv_files = glob.glob(os.path.join(self.data_path, "*.csv"))
        if not csv_files:
            raise FileNotFoundError(f"No CSV files found in {self.data_path}")
            
        for csv_file in csv_files:
            table_name = os.path.basename(csv_file).replace(".csv", "")
            self.con.execute(f"CREATE OR REPLACE TABLE {table_name} AS SELECT * FROM read_csv_auto('{csv_file}')")
            self.tables.append(table_name)
        return self

    def validate(self, tests_dir=None):
        """Runs all SQL validation tests against the loaded data."""
        if tests_dir is None:
            tests_dir = Path(__file__).parent / "tests"
            
        test_files = sorted(glob.glob(os.path.join(tests_dir, "*.sql")))
        validation_results = {}
        total_issues = 0

        print(f"\n--- Running Validations for {self.data_path} ---")
        for test_file in test_files:
            test_name = os.path.basename(test_file)
            with open(test_file, 'r') as f:
                query = f.read()
            
            try:
                result = self.con.execute(query).df()
                if not result.empty:
                    print(f"❌ {test_name}: {len(result)} issues found")
                    validation_results[test_name] = result
                    total_issues += len(result)
                else:
                    print(f"✅ {test_name}: Passed")
            except Exception as e:
                print(f"⚠️ {test_name}: Failed to execute - {e}")
        
        return total_issues == 0, validation_results

class LoanMetricsRunner:
    """
    Executes business metrics and analytical queries.
    """
    def __init__(self, loader: LoanDataLoader):
        self.loader = loader
        self.con = loader.con

    def run_loan_state(self, output_path=None):
        """Calculates monthly loan states and saves to CSV."""
        print("\n--- Calculating Loan States ---")
        sql_path = Path(__file__).parent / "sql" / "recursive_loan_state.sql"
        
        with open(sql_path, 'r') as f:
            query = f.read()
            
        if output_path is None:
            output_path = os.path.join(self.loader.data_path, "processed_loan_state.csv")

        try:
            self.con.execute(query)
            self.con.execute(f"COPY loan_state TO '{output_path}' (HEADER, DELIMITER ',')")
            print(f"✅ Loan State results saved to: {output_path}")
            return output_path
        except Exception as e:
            print(f"❌ Loan State engine failed: {e}")

    def run_delinquency(self, output_path=None):
        """Calculates delinquency and DPD categories, and saves results to CSV."""
        print("--- Calculating Delinquency Metrics ---")
        sql_path = Path(__file__).parent / "sql" / "instalment_delinquency_maker.sql"
        
        with open(sql_path, 'r') as f:
            query = f.read()

        if output_path is None:
            output_path = os.path.join(self.loader.data_path, "processed_delinquency.csv")

        try:
            self.con.execute(f"CREATE OR REPLACE TABLE instalment_delinquency AS {query}")
            self.con.execute(f"COPY instalment_delinquency TO '{output_path}' (HEADER, DELIMITER ',')")
            print(f"✅ Delinquency metrics saved to: {output_path}")
            return output_path
        except Exception as e:
            print(f"❌ Delinquency calculation failed: {e}")
