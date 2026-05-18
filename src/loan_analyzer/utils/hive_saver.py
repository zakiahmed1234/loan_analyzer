import os
import pandas as pd
from pathlib import Path

def save_hive_partitioned(df, base_dir, category, item_name, lender_id, output_format="parquet"):
    """
    Saves a DataFrame into a Hive-partitioned directory structure.
    Structure: base_dir/category/item_name/lender_id=<lender_id>/year=.../month=.../day=.../
    
    Args:
        df (pd.DataFrame): Data to save.
        base_dir (str): Root directory for storage.
        category (str): Data category (e.g., 'core', 'metrics').
        item_name (str): Specific item name (e.g., 'loan_state', 'actual_payments').
        lender_id (str): The lender identifier.
        output_format (str): 'parquet' or 'csv' (default: 'parquet').
    """
    if df.empty:
        print(f"Skipping save for {item_name}: DataFrame is empty.")
        return

    # Ensure lender_id is in the dataframe if not already there
    if 'lender_id' not in df.columns:
        df['lender_id'] = lender_id

    # Standardize partition columns
    partition_cols = ['lender_id']
    for col in ['year', 'month', 'day']:
        if col in df.columns:
            partition_cols.append(col)

    # Define the output path
    output_path = Path(base_dir) / category / item_name
    output_path.mkdir(parents=True, exist_ok=True)

    print(f"Saving {item_name} to {output_path} in Hive format ({output_format})...")

    if output_format.lower() == "parquet":
        # use fastparquet or pyarrow if available, otherwise fallback
        try:
            df.to_parquet(
                output_path,
                partition_cols=partition_cols,
                index=False,
                engine='pyarrow'
            )
        except Exception as e:
            print(f"Failed to save as parquet using pyarrow: {e}. Falling back to single file.")
            df.to_parquet(output_path / f"{item_name}.parquet", index=False)
    else:
        # For CSV, pandas doesn't support partition_cols directly in a Hive-way as easily as parquet
        # We'll just save it as a single file for now or implement manual partitioning if needed
        # But usually Hive-partitioned implies Parquet.
        df.to_csv(output_path / f"{item_name}.csv", index=False)

    print(f"✅ Saved {item_name} successfully.")
