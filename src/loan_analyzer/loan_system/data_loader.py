import duckdb
import os
from pathlib import Path

class DataLoader:
    """
    Loads CSV files from a directory into DuckDB tables.
    """
    def __init__(self, directory_path: str, connection: duckdb.DuckDBPyConnection = None):
        self.directory_path = Path(directory_path)
        self.con = connection if connection else duckdb.connect(database=':memory:')
        self._load_csv_files()

    def _load_csv_files(self):
        """
        Iterates through the directory and creates tables for each CSV file.
        """
        if not self.directory_path.exists():
            raise FileNotFoundError(f"Directory {self.directory_path} does not exist.")

        for file in self.directory_path.glob("*.csv"):
            table_name = file.stem
            print(f"Loading {file.name} into table '{table_name}'...")
            self.con.execute(f"CREATE TABLE {table_name} AS SELECT * FROM read_csv_auto('{file}')")

    def get_connection(self):
        return self.con
