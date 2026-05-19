import sys
import os
from src.loan_analyzer.core.loan_system.data_loader import DataLoader
from src.loan_analyzer.core.loan_system.validation import DataValidation

def run_validation(data_dir):
    print(f"\n--- Validating data in {data_dir} ---")
    try:
        loader = DataLoader(data_dir)
        validator = DataValidation(loader)
        results = validator.validate_all()
        
        print(results[['check_name', 'passed', 'details']])
        
        all_passed = results['passed'].all()
        if all_passed:
            print(f"Result: All checks PASSED for {data_dir}")
        else:
            print(f"Result: Some checks FAILED for {data_dir}")
        return all_passed
    except Exception as e:
        print(f"Error during validation of {data_dir}: {e}")
        return False

if __name__ == "__main__":
    perfect_passed = run_validation("sample_data/perfect")
    error_passed = run_validation("sample_data/error")
    
    if perfect_passed and not error_passed:
        print("\nSUCCESS: Perfect data passed and Error data failed as expected.")
    else:
        print("\nFAILURE: Data validation results did not match expectations.")
        sys.exit(1)
