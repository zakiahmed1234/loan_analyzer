/* This calculates loss given default. In particular, if a loan status changed to defaulted, we then find the collateral valuation and compare that to the total principal paid off, and calculate the difference */


--
-- -- 1️⃣ Get the latest valuation per collateral 
-- CREATE OR REPLACE TEMP VIEW latest_collateral_valuation AS
-- SELECT 
--     collateral_id,
--     collateral_value,
--     valuation_date,
--     ROW_NUMBER() OVER (PARTITION BY collateral_id ORDER BY valuation_date DESC) as recent_rank
-- FROM collateral_valuation;
--
-- -- 2️⃣ Identify the latest principal balance for defaulted loans and calculate LGD
-- CREATE OR REPLACE TABLE loss_given_default_report AS
-- WITH latest_loan_state AS (
--     -- Get the most recent delinquency record for every loan to find the current principal "out by"
--     SELECT 
--         loan_id,
--         closing_principal,
--         dpd_category,
--         scheduled_instalment_date,
--         ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY scheduled_instalment_date DESC) as latest_rank
--     FROM instalment_delinquency
-- )
--
--
--
-- SELECT 
--     l.loan_id,
--     l.loan_status,
--     ls.closing_principal AS exposure_at_default,
--     ls.dpd_category,
--     c.collateral_type,
--     COALESCE(cv.collateral_value, 0) AS collateral_recovery_value,
--     -- Calculation: Principal Owed - Collateral Value
--     GREATEST(ls.closing_principal - COALESCE(cv.collateral_value, 0), 0) AS net_loss_amount,
--     -- LGD %: (Net Loss / Exposure)
--     CASE 
--         WHEN ls.closing_principal > 0 
--         THEN (GREATEST(ls.closing_principal - COALESCE(cv.collateral_value, 0), 0) / ls.closing_principal) 
--         ELSE 0 
--     END AS lgd_rate
-- FROM loans l
-- JOIN latest_loan_state ls 
--     ON l.loan_id = ls.loan_id 
--     AND ls.latest_rank = 1
-- LEFT JOIN collateral c 
--     ON l.loan_id = c.loan_id
-- LEFT JOIN latest_collateral_valuation cv 
--     ON c.collateral_id = cv.collateral_id 
--     AND cv.recent_rank = 1


-- Consolidation of Logic for Loss Given Default Report
WITH latest_collateral_valuation AS (
    SELECT 
        collateral_id,
        collateral_value,
        CAST(valuation_date AS DATE) as valuation_date_dt,
        ROW_NUMBER() OVER (PARTITION BY collateral_id ORDER BY CAST(valuation_date AS DATE) DESC) as recent_rank
    FROM collateral_valuation
    WHERE lender_id = ${lender_id}
      AND (year, month, day) BETWEEN (${start_year}, ${start_month}, ${start_day})
                              AND (${end_year}, ${end_month}, ${end_day})
),
latest_loan_state AS (
    SELECT 
        loan_id,
        closing_principal,
        dpd_category,
        CAST(scheduled_instalment_date AS DATE) as instalment_date_dt,
        ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY CAST(scheduled_instalment_date AS DATE) DESC) as latest_rank
    FROM instalment_delinquency
)

SELECT 
    l.loan_id,
    l.loan_status,
    ls.closing_principal AS exposure_at_default,
    ls.dpd_category,
    c.collateral_type,
    COALESCE(cv.collateral_value, 0) AS collateral_recovery_value,
    -- Calculation: Principal Owed - Collateral Value
    GREATEST(ls.closing_principal - COALESCE(cv.collateral_value, 0), 0) AS net_loss_amount,
    -- LGD %: (Net Loss / Exposure) * 100.0 for float precision
    CASE 
        WHEN ls.closing_principal > 0 
        THEN (GREATEST(ls.closing_principal - COALESCE(cv.collateral_value, 0), 0) / CAST(ls.closing_principal AS DOUBLE)) * 100.0
        ELSE 0.0 
    END AS lgd_rate_pct
FROM loans l
JOIN latest_loan_state ls
    ON l.loan_id = ls.loan_id
    AND ls.latest_rank = 1
LEFT JOIN collateral c
    ON l.loan_id = c.loan_id
    AND c.lender_id = ${lender_id}
LEFT JOIN latest_collateral_valuation cv
    ON c.collateral_id = cv.collateral_id
    AND cv.recent_rank = 1
WHERE
    l.lender_id = ${lender_id}
    AND (l.year, l.month, l.day) BETWEEN (${start_year}, ${start_month}, ${start_day}) AND (${end_year}, ${end_month}, ${end_day})
    AND LOWER(l.loan_status) LIKE '%default%'
-- Shorthand sorting
ORDER BY 8 DESC;
