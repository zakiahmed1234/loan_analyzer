import datetime
import re
from pathlib import Path
import pandas as pd
import sqlglot
from sqlglot import exp

class BaseMetrics:
    """
    Base class for executing metrics and saving them in Hive-partitioned Parquet format.
    Supports secure, multi-dialect SQL translation using stable sqlglot AST parsing.
    """
    def __init__(self, calculation, registry, category_name):
        self.calculation = calculation
        self.con = calculation.con
        self.lender_id = calculation.validator.loader.lender_id
        self.registry = registry
        self.category_name = category_name
        # Path to the specific metric category's SQL folder
        self.sql_base_path = Path(__file__).parent / category_name / "sql"

    def run_metric(self, metric_name, output_base_dir=".", dialect="duckdb", output_format="parquet"):
        """
        Runs a specific metric and saves the result.
        Uses sqlglot to parse into an AST, securely maps parameters using stable 
        type-safe Literal expressions, and transpiles to the target engine dialect.
        
        Args:
            metric_name (str): The name of the metric in the registry.
            output_base_dir (str): Root directory for saving results.
            dialect (str): The SQL dialect to transpile to (default: duckdb).
            output_format (str): 'parquet' or 'csv' (default: parquet).
        """
        if metric_name not in self.registry:
            raise ValueError(f"Metric '{metric_name}' not found in {self.category_name} metrics registry.")

        metric_config = self.registry[metric_name]
        sql_file_name = metric_config if isinstance(metric_config, str) else metric_config["file"]
        sql_file = self.sql_base_path / sql_file_name

        with open(sql_file, 'r') as f:
            raw_query = f.read()

        # Define universal parameter payload mapping
        params = {
            "lender_id": str(self.lender_id),
            "start_year": 1900,
            "start_month": 1,
            "start_day": 1,
            "end_year": 2100,
            "end_month": 12,
            "end_day": 31
        }

        # 1. Standardize variable formats ($name or ${name} -> :name) 
        # This guarantees that the core Trino parser reads them cleanly as placeholders
        import re
        processed_query = re.sub(r'\$\{(\w+)\}', r':\1', raw_query)
        processed_query = re.sub(r'\$(\w+)', r':\1', processed_query)

        print(f"Parsing {self.category_name} metric: {metric_name} for target dialect: {dialect}...")

        try:
            # 2. Parse the sanitized Trino framework file into a structural AST
            expression = sqlglot.parse_one(processed_query, read="trino")
            
            # 3. Standard AST-Safe Parameter Injection 
            # We transform explicit placeholder nodes into compiled, escaped literals
            def replace_placeholders(node):
                if isinstance(node, exp.Placeholder) and node.name in params:
                    val = params[node.name]
                    # Convert to a literal node type based on Python primitive type
                    if isinstance(val, (int, float)):
                        return exp.Literal.number(val)
                    return exp.Literal.string(str(val))
                return node

            # Apply the mapping transformation safely across the expression tree
            bound_expression = expression.transform(replace_placeholders)
            query = bound_expression.sql(dialect=dialect)
            
        except Exception as e:
            print(f"Warning: sqlglot AST pipeline failed for '{metric_name}'. Falling back. Error: {e}")
            # Secure fallback backup execution block
            query = processed_query
            for name, val in params.items():
                sanitized_val = str(val).replace("'", "''")  # Basic single-quote escape guard
                query = query.replace(f":{name}", f"'{sanitized_val}'" if isinstance(val, str) else str(val))

        # 4. Execute the fully rendered, injection-safe SQL query string
        df = self.con.execute(query).df()

        # Save using the centralized utility
        from ..utils.hive_saver import save_hive_partitioned
        save_hive_partitioned(
            df=df,
            base_dir=output_base_dir,
            category=f"{self.category_name}_metrics",
            item_name=metric_name,
            lender_id=self.lender_id,
            output_format=output_format
        )
        
        return df
