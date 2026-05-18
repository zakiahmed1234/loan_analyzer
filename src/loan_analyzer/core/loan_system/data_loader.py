import duckdb
import os
import uuid
from pathlib import Path

class DataLoader:
    """
    Loads CSV files from a directory into DuckDB tables.
    """
    REQUIRED_FILES = [
        "actual_payments.csv",
        "borrowers.csv",
        "collateral_valuation.csv",
        "collateral.csv",
        "lender.csv",
        "loans.csv",
        "scheduled_repayments.csv"
    ]

    def __init__(self, directory_path: str, connection: duckdb.DuckDBPyConnection = None, lender_id: str = None):
        self.directory_path = Path(directory_path)
        self.con = connection if connection else duckdb.connect(database=':memory:')
        self.lender_id = lender_id if lender_id else f"LENDER_ID_{uuid.uuid4().hex[:8]}"
        self._load_csv_files()

    def _load_csv_files(self):
        """
        Iterates through the directory and creates tables for each CSV file.
        Enforces that all required files are present.
        """
        if not self.directory_path.exists():
            raise FileNotFoundError(f"Directory {self.directory_path} does not exist.")

        missing_files = []
        for req_file in self.REQUIRED_FILES:
            if not (self.directory_path / req_file).exists():
                missing_files.append(req_file)
        
        if missing_files:
            raise FileNotFoundError(f"Missing required CSV files in {self.directory_path}: {', '.join(missing_files)}")

        for file in self.directory_path.glob("*.csv"):
            table_name = file.stem
            print(f"Loading {file.name} into table '{table_name}'...")
            self.con.execute(f"CREATE TABLE {table_name} AS SELECT * FROM read_csv_auto('{file}')")
            
            # Ensure lender_id column exists for metric filtering
            columns = self.con.execute(f"PRAGMA table_info('{table_name}')").fetchall()
            column_names = [col[1] for col in columns]
            if 'lender_id' not in column_names:
                print(f"Injecting lender_id '{self.lender_id}' into table '{table_name}'...")
                self.con.execute(f"ALTER TABLE {table_name} ADD COLUMN lender_id VARCHAR")
                self.con.execute(f"UPDATE {table_name} SET lender_id = ?", [self.lender_id])
            
            # Inject year, month, day partitions if date columns exist
            date_col = None
            for candidate in ['origination_date', 'actual_payment_date', 'scheduled_instalment_date', 'signup_month', 'valuation_date']:
                if candidate in column_names:
                    date_col = candidate
                    break
            
            if date_col:
                print(f"Injecting year, month, day partitions from {date_col} into table '{table_name}'...")
                if 'year' not in column_names:
                    self.con.execute(f"ALTER TABLE {table_name} ADD COLUMN year INTEGER")
                    self.con.execute(f"UPDATE {table_name} SET year = EXTRACT(YEAR FROM CAST({date_col} AS DATE))")
                if 'month' not in column_names:
                    self.con.execute(f"ALTER TABLE {table_name} ADD COLUMN month INTEGER")
                    self.con.execute(f"UPDATE {table_name} SET month = EXTRACT(MONTH FROM CAST({date_col} AS DATE))")
                if 'day' not in column_names:
                    self.con.execute(f"ALTER TABLE {table_name} ADD COLUMN day INTEGER")
                    self.con.execute(f"UPDATE {table_name} SET day = EXTRACT(DAY FROM CAST({date_col} AS DATE))")

    def get_connection(self):
        return self.con
