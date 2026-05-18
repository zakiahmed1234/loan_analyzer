SELECT 
    (SELECT typeof(loan_amount) FROM loans LIMIT 1) as loan_amt_type,
    (SELECT typeof(origination_date) FROM loans LIMIT 1) as orig_date_type,
    (SELECT typeof(actual_total_amount) FROM actual_payments LIMIT 1) as pay_amt_type;