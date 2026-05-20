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

def generate_data(base_path, perfect=True, lender_id="LEND_001"):
    # Setup - Denser dataset
    num_borrowers = 50
    num_loans = 200
    start_date = datetime(2021, 1, 1)
    
    borrower_ids = [f"BORR_{i:03d}" for i in range(1, num_borrowers + 1)]
    loan_ids = [f"LOAN_{i:03d}" for i in range(1, num_loans + 1)]
    
    # 1. Lender
    lenders = [{"lender_id": lender_id, "lender_name": "Standard Lending Corp"}]
    save_csv(os.path.join(base_path, "lender.csv"), lenders, ["lender_id", "lender_name"])

    # 2. Borrowers
    borrowers = []
    for bid in borrower_ids:
        # Signup spread across first year
        signup = start_date + timedelta(days=random.randint(0, 365))
        borrowers.append({
            "borrower_id": bid,
            "name": f"Borrower {bid}",
            "signup_month": signup.strftime("%Y-%m-01"),
            "location_country": "USA",
            "location_state_province": random.choice(['NY', 'CA', 'TX', 'FL', 'IL'])
        })
    save_csv(os.path.join(base_path, "borrowers.csv"), borrowers, ["borrower_id", "name", "signup_month", "location_country", "location_state_province"])

    # 3. Loans
    loans = []
    for i, lid in enumerate(loan_ids):
        # Origination spread across 2 years
        orig_date = start_date + timedelta(days=random.randint(0, 730))
        maturity_date = orig_date + timedelta(days=random.choice([365, 730]))
        loan_amount = random.choice([5000, 10000, 15000, 20000])
        interest_rate = random.uniform(8.0, 18.0)
        
        loan_status = "Active"
        roll = random.random()
        if roll > 0.8: loan_status = "PaidOff"
        elif roll > 0.7: loan_status = "Defaulted"
            
        loans.append({
            "loan_id": lid,
            "borrower_id": random.choice(borrower_ids),
            "loan_amount": loan_amount,
            "interest_rate": interest_rate,
            "origination_date": orig_date.strftime("%Y-%m-%d"),
            "maturity_date": maturity_date.strftime("%Y-%m-%d"),
            "lender_id": lender_id,
            "loan_status": loan_status,
            "loan_grade": random.choice(['A', 'B', 'C', 'D']),
            "loan_use": random.choice(['Education', 'Home Improvement', 'Business', 'Medical', 'Debt Cons']),
            "origination_month": orig_date.strftime("%Y-%m-01"),
            "credit_bureau_score": random.randint(550, 850),
            "internal_score": random.randint(400, 750),
            "origination_fee_amount": loan_amount * 0.02,
            "loan_sequence_number": random.randint(1, 3)
        })
    save_csv(os.path.join(base_path, "loans.csv"), loans, ["loan_id", "borrower_id", "loan_amount", "interest_rate", "origination_date", "maturity_date", "lender_id", "loan_status", "loan_grade", "loan_use", "origination_month", "credit_bureau_score", "internal_score", "origination_fee_amount", "loan_sequence_number"])

    # 4. Scheduled Repayments
    scheduled = []
    for l in loans:
        lid = l["loan_id"]
        l_amt = l["loan_amount"]
        orig_date = datetime.strptime(l["origination_date"], "%Y-%m-%d")
        mat_date = datetime.strptime(l["maturity_date"], "%Y-%m-%d")
        months = (mat_date.year - orig_date.year) * 12 + (mat_date.month - orig_date.month)
        
        for inst_num in range(1, months + 1):
            inst_date = orig_date + timedelta(days=inst_num * 30)
            scheduled.append({
                "loan_id": lid,
                "scheduled_instalment_date": inst_date.strftime("%Y-%m-%d"),
                "scheduled_principal": l_amt / months,
                "scheduled_interest": (l_amt * (l["interest_rate"]/100) / 12),
                "scheduled_fees": 5.0,
                "scheduled_vat": 1.0
            })
    save_csv(os.path.join(base_path, "scheduled_repayments.csv"), scheduled, ["loan_id", "scheduled_instalment_date", "scheduled_principal", "scheduled_interest", "scheduled_fees", "scheduled_vat"])

    # 5. Actual Payments
    payments = []
    pay_id_counter = 1
    for l in loans:
        lid = l["loan_id"]
        l_amt = l["loan_amount"]
        loan_status = l["loan_status"]
        orig_date = datetime.strptime(l["origination_date"], "%Y-%m-%d")
        mat_date = datetime.strptime(l["maturity_date"], "%Y-%m-%d")
        months = (mat_date.year - orig_date.year) * 12 + (mat_date.month - orig_date.month)
        
        num_pays = months if loan_status == "PaidOff" else random.randint(1, months)
        if loan_status == "Defaulted" and num_pays > 6: num_pays = 6 # Faster defaults
        
        for m in range(1, num_pays + 1):
            pay_date = orig_date + timedelta(days=m * 30)
            # Add some randomness to payment dates to create delinquency
            if random.random() > 0.9: 
                pay_date += timedelta(days=random.randint(5, 45))
                
            payments.append({
                "loan_id": lid,
                "payment_id": f"PAY_{pay_id_counter:05d}",
                "actual_payment_date": pay_date.strftime("%Y-%m-%d"),
                "actual_principal": l_amt / months,
                "actual_interest": (l_amt * (l["interest_rate"]/100) / 12),
                "actual_fees": 5.0,
                "actual_total_amount": (l_amt / months) + (l_amt * (l["interest_rate"]/100) / 12) + 5.0,
                "write_off_amount": 0.0,
                "penalty_amount": 0.0
            })
            pay_id_counter += 1
    save_csv(os.path.join(base_path, "actual_payments.csv"), payments, ["loan_id", "payment_id", "actual_payment_date", "actual_principal", "actual_interest", "actual_fees", "actual_total_amount", "write_off_amount", "penalty_amount"])

    # 6. Collateral & 7. Valuations
    collaterals = []
    valuations = []
    for i, l in enumerate(loans):
        cid = f"COLL_{i:04d}"
        collaterals.append({"collateral_id": cid, "loan_id": l["loan_id"], "collateral_type": "Vehicle"})
        valuations.append({"collateral_id": cid, "valuation_date": l["origination_date"], "collateral_value": l["loan_amount"] * 1.5})
    
    save_csv(os.path.join(base_path, "collateral.csv"), collaterals, ["collateral_id", "loan_id", "collateral_type"])
    save_csv(os.path.join(base_path, "collateral_valuation.csv"), valuations, ["collateral_id", "valuation_date", "collateral_value"])

if __name__ == "__main__":
    generate_data("sample_data/perfect", perfect=True)
    print("Generated data in sample_data/perfect")
