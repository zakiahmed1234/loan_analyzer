/* in this we deduce the status distrubtion over vintage. In particular, for a specific origination month, we record the first 12 months, and for every month we list all loans along with their respective status. We then range over origination month */

WITH mob_series AS (
    SELECT range as mob
    FROM range(0, 13)
),

loan_base AS (
    SELECT 
        l.loan_id,
        CAST(l.origination_date AS DATE) AS origination_date,
        CAST(DATE_TRUNC('month', CAST(l.origination_date AS DATE)) AS DATE) AS vintage,
        l.loan_status AS current_final_status,
        m.mob,
        CAST(CAST(l.origination_date AS DATE) + (m.mob * INTERVAL '1 month') AS DATE) AS observation_month
    FROM loans l
    CROSS JOIN mob_series m
    WHERE
        l.lender_id = ${lender_id}
        AND (
            l.year > ${start_year} OR
            (l.year = ${start_year} AND l.month > ${start_month}) OR
            (l.year = ${start_year} AND l.month = ${start_month} AND l.day >= ${start_day})
        )
        AND (
            l.year < ${end_year} OR
            (l.year = ${end_year} AND l.month < ${end_month}) OR
            (l.year = ${end_year} AND l.month = ${end_month} AND l.day <= ${end_day})
        )
),

payment_summary AS (
    SELECT 
        loan_id, 
        MAX(CAST(actual_payment_date AS DATE)) AS last_pay_date
    FROM actual_payments
    WHERE lender_id = ${lender_id}
          AND (
              year > ${start_year} OR
              (year = ${start_year} AND month > ${start_month}) OR
              (year = ${start_year} AND month = ${start_month} AND day >= ${start_day})
          )
          AND (
              year < ${end_year} OR
              (year = ${end_year} AND month < ${end_month}) OR
              (year = ${end_year} AND month = ${end_month} AND day <= ${end_day})
          )
    GROUP BY 1
)

SELECT 
    b.vintage,
    b.loan_id,
    b.mob,
    CASE 
        WHEN b.current_final_status = 'Canceled' THEN 'Canceled'
        
        WHEN b.current_final_status = 'PaidOff' 
             AND b.observation_month > p.last_pay_date THEN 'PaidOff'
        
        WHEN b.current_final_status = 'Defaulted' 
             AND b.observation_month >= CAST(p.last_pay_date AS DATE) + INTERVAL '3 months' THEN 'Defaulted'
        
        ELSE 'Active'
    END AS status_at_mob
FROM loan_base b
LEFT JOIN payment_summary p ON b.loan_id = p.loan_id
ORDER BY 1 DESC, 2, 3 ASC;
