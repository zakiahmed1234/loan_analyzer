import csv
import os
import random
from datetime import datetime, timedelta

def save_csv(filename, data, fieldnames):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)

def generate_data(base_path, perfect=True):
    # Setup
    lender_id = "LEND_001"
    borrower_ids = [f"BORR_{i:03d}" for i in range(1, 6)]
    loan_ids = [f"LOAN_{i:03d}" for i in range(1, 11)]
    
    # 1. Lender
    lenders = [{"lender_id": lender_id, "lender_name": "Perfect Lending Corp" if perfect else "Chaos Bank"}]
    save_csv(os.path.join(base_path, "lender.csv"), lenders, ["lender_id", "lender_name"])

    # 2. Borrowers
    borrowers = []
    for bid in borrower_ids:
        borrowers.append({
            "borrower_id": bid,
            "name": f"Borrower {bid}",
            "signup_month": "2023-01-01"
        })
    if not perfect:
        # Duplicate borrower ID
        borrowers.append(borrowers[0].copy())
    save_csv(os.path.join(base_path, "borrowers.csv"), borrowers, ["borrower_id", "name", "signup_month"])

    # 3. Loans
    loans = []
    for i, lid in enumerate(loan_ids):
        orig_date = datetime(2023, 1, 1) + timedelta(days=i*30)
        maturity_date = orig_date + timedelta(days=365)
        loan_amount = 10000.0
        loan_status = "Active"
        
        if not perfect and i == 0:
            loan_amount = -5000.0 # Negative loan amount
        if not perfect and i == 1:
            maturity_date = orig_date - timedelta(days=30) # Maturity before origination
        
        if perfect and i == 9:
            loan_status = "PaidOff" # For terminal state test
            
        loans.append({
            "loan_id": lid,
            "borrower_id": borrower_ids[i % len(borrower_ids)],
            "loan_amount": loan_amount,
            "interest_rate": 12.0,
            "origination_date": orig_date.strftime("%Y-%m-%d"),
            "maturity_date": maturity_date.strftime("%Y-%m-%d"),
            "lender_id": lender_id,
            "loan_status": loan_status
        })
    save_csv(os.path.join(base_path, "loans.csv"), loans, ["loan_id", "borrower_id", "loan_amount", "interest_rate", "origination_date", "maturity_date", "lender_id", "loan_status"])

    # 4. Scheduled Repayments
    scheduled = []
    for i, lid in enumerate(loan_ids):
        l_amt = next(l for l in loans if l["loan_id"] == lid)["loan_amount"]
        orig_date = datetime.strptime(next(l for l in loans if l["loan_id"] == lid)["origination_date"], "%Y-%m-%d")
        
        num_instalments = 12
        princ_per_inst = l_amt / num_instalments
        
        for inst_num in range(1, num_instalments + 1):
            inst_date = orig_date + timedelta(days=inst_num * 30)
            scheduled.append({
                "loan_id": lid,
                "scheduled_instalment_date": inst_date.strftime("%Y-%m-%d"),
                "scheduled_principal": princ_per_inst,
                "scheduled_interest": (l_amt * 0.01), # Simple 1% monthly interest
                "scheduled_fees": 10.0,
                "scheduled_vat": 2.0
            })
    save_csv(os.path.join(base_path, "scheduled_repayments.csv"), scheduled, ["loan_id", "scheduled_instalment_date", "scheduled_principal", "scheduled_interest", "scheduled_fees", "scheduled_vat"])

    # 5. Actual Payments
    payments = []
    pay_id_counter = 1
    for i, lid in enumerate(loan_ids):
        l_amt = next(l for l in loans if l["loan_id"] == lid)["loan_amount"]
        loan_status = next(l for l in loans if l["loan_id"] == lid)["loan_status"]
        orig_date = datetime.strptime(next(l for l in loans if l["loan_id"] == lid)["origination_date"], "%Y-%m-%d")
        
        if not perfect and i == 2:
            # Payment before origination
            payments.append({
                "loan_id": lid,
                "payment_id": f"PAY_{pay_id_counter:04d}",
                "actual_payment_date": (orig_date - timedelta(days=5)).strftime("%Y-%m-%d"),
                "actual_principal": 100.0,
                "actual_interest": 10.0,
                "actual_fees": 0.0,
                "actual_total_amount": 110.0,
                "write_off_amount": 0.0,
                "penalty_amount": 0.0
            })
            pay_id_counter += 1
            
        if not perfect and i == 3:
            # Overpayment leading to negative balance
            payments.append({
                "loan_id": lid,
                "payment_id": f"PAY_{pay_id_counter:04d}",
                "actual_payment_date": (orig_date + timedelta(days=5)).strftime("%Y-%m-%d"),
                "actual_principal": l_amt + 1000.0,
                "actual_interest": 100.0,
                "actual_fees": 0.0,
                "actual_total_amount": l_amt + 1100.0,
                "write_off_amount": 0.0,
                "penalty_amount": 0.0
            })
            pay_id_counter += 1
            
        if not perfect and i == 4:
            # Duplicate payment ID
            pid = f"PAY_{pay_id_counter:04d}"
            p_data = {
                "loan_id": lid,
                "payment_id": pid,
                "actual_payment_date": (orig_date + timedelta(days=5)).strftime("%Y-%m-%d"),
                "actual_principal": 100.0,
                "actual_interest": 10.0,
                "actual_fees": 0.0,
                "actual_total_amount": 110.0,
                "write_off_amount": 0.0,
                "penalty_amount": 0.0
            }
            payments.append(p_data)
            payments.append(p_data.copy())
            pay_id_counter += 1
        
        if perfect:
            if loan_status == "PaidOff":
                # Generate full payments to reach PaidOff state
                for m in range(1, 13):
                    pay_date = orig_date + timedelta(days=m * 30)
                    payments.append({
                        "loan_id": lid,
                        "payment_id": f"PAY_{pay_id_counter:04d}",
                        "actual_payment_date": pay_date.strftime("%Y-%m-%d"),
                        "actual_principal": l_amt / 12,
                        "actual_interest": (l_amt * 0.01),
                        "actual_fees": 10.0,
                        "actual_total_amount": (l_amt / 12) + (l_amt * 0.01) + 10.0,
                        "write_off_amount": 0.0,
                        "penalty_amount": 0.0
                    })
                    pay_id_counter += 1
            else:
                # Generate 3 months of perfect payments
                for m in range(1, 4):
                    pay_date = orig_date + timedelta(days=m * 30)
                    payments.append({
                        "loan_id": lid,
                        "payment_id": f"PAY_{pay_id_counter:04d}",
                        "actual_payment_date": pay_date.strftime("%Y-%m-%d"),
                        "actual_principal": l_amt / 12,
                        "actual_interest": (l_amt * 0.01),
                        "actual_fees": 10.0,
                        "actual_total_amount": (l_amt / 12) + (l_amt * 0.01) + 10.0,
                        "write_off_amount": 0.0,
                        "penalty_amount": 0.0
                    })
                    pay_id_counter += 1
        elif i > 4:
            # Normal-ish payments for the rest of the error set
            pay_date = orig_date + timedelta(days=30)
            payments.append({
                "loan_id": lid,
                "payment_id": f"PAY_{pay_id_counter:04d}",
                "actual_payment_date": pay_date.strftime("%Y-%m-%d"),
                "actual_principal": 100.0,
                "actual_interest": 10.0,
                "actual_fees": 0.0,
                "actual_total_amount": 110.0,
                "write_off_amount": 0.0,
                "penalty_amount": 0.0
            })
            pay_id_counter += 1

    save_csv(os.path.join(base_path, "actual_payments.csv"), payments, ["loan_id", "payment_id", "actual_payment_date", "actual_principal", "actual_interest", "actual_fees", "actual_total_amount", "write_off_amount", "penalty_amount"])

    # 6. Collateral
    collaterals = []
    for i, lid in enumerate(loan_ids):
        collaterals.append({
            "collateral_id": f"COLL_{i:03d}",
            "loan_id": lid,
            "collateral_type": "Vehicle" if i % 2 == 0 else "Property"
        })
    save_csv(os.path.join(base_path, "collateral.csv"), collaterals, ["collateral_id", "loan_id", "collateral_type"])

    # 7. Collateral Valuation
    valuations = []
    for i, lid in enumerate(loan_ids):
        cid = f"COLL_{i:03d}"
        orig_date = datetime.strptime(next(l for l in loans if l["loan_id"] == lid)["origination_date"], "%Y-%m-%d")
        valuations.append({
            "collateral_id": cid,
            "valuation_date": orig_date.strftime("%Y-%m-%d"),
            "collateral_value": 15000.0 if perfect else (15000.0 if i != 5 else -100.0) # Negative valuation in error data
        })
    save_csv(os.path.join(base_path, "collateral_valuation.csv"), valuations, ["collateral_id", "valuation_date", "collateral_value"])

if __name__ == "__main__":
    generate_data("sample_data/perfect", perfect=True)
    generate_data("sample_data/error", perfect=False)
    print("Generated perfect data in sample_data/perfect")
    print("Generated error data in sample_data/error")
