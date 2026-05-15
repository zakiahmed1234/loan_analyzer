import duckdb
from pathlib import Path
from .data_loader import DataLoader

class DataValidation:
    """
    Validates loan data invariants using DuckDB SQL files.
    """
    def __init__(self, loader: DataLoader):
        self.loader = loader
        self.con = loader.get_connection()
        self.tests_path = Path(__file__).parent.parent / "tests" / "data_validation"
        self._setup_validation_table()

    def _setup_validation_table(self):
        setup_sql = self.tests_path / "setup_validation.sql"
        with open(setup_sql, 'r') as f:
            self.con.execute(f.read())

    def _record_result(self, name, passed, details=""):
        self.con.execute("INSERT INTO validation_results (check_name, passed, details) VALUES (?, ?, ?)", 
                         (name, passed, str(details)))

    def _run_sql_check(self, sql_file):
        name = sql_file.stem
        with open(sql_file, 'r') as f:
            query = f.read()
        
        try:
            res = self.con.execute(query).fetchone()
            # Standardized logic: 0 means pass, >0 means fail
            if name == "test_data_types":
                passed = True # Metadata check
                details = str(res)
            elif name == "test_schema_names":
                passed = res[0] == 3
                details = f"Tables found: {res[0]}" if not passed else "Schema valid."
            else:
                passed = res[0] == 0
                details = f"Violations found: {res[0]}" if not passed else "Check passed."
            
            self._record_result(name, passed, details)
            return passed
        except Exception as e:
            self._record_result(name, False, str(e))
            return False

    def validate_all(self):
        """
        Iterates through all test_*.sql files in the tests/data_validation directory.
        """
        results = []
        for sql_file in sorted(self.tests_path.glob("test_*.sql")):
            results.append(self._run_sql_check(sql_file))
        
        return self.con.execute("SELECT * FROM validation_results").df()
