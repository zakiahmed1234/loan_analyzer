/* In this, we measure how the predictive power of our internal and credit scores change dependent on the origination date. In particular, for each origination month, we record the dpd rates in a 6 month horizon post origination, aggregated by internal and credit score bands.*/
--
-- WITH mob6_snapshot AS (
--     -- 1. Identify loans that have hit at least 6 months on books
--     -- 2. Grab their specific DPD state at that exact milestone
--     SELECT 
--         l.loan_id,
--         DATE_TRUNC('month', CAST(l.origination_date AS DATE)) AS vintage,
--         l.loan_amount,
--         -- Score Banding (Adjust these ranges based on your actual score distributions)
--         CASE 
--             WHEN l.credit_bureau_score >= 720 THEN '720+ (Prime)'
--             WHEN l.credit_bureau_score >= 660 THEN '660-719 (Near-Prime)'
--             ELSE 'Below 660 (Sub-Prime)'
--         END AS bureau_band,
--         CASE 
--             WHEN l.internal_score >= 80 THEN 'High (80+)'
--             WHEN l.internal_score >= 50 THEN 'Med (50-79)'
--             ELSE 'Low (<50)'
--         END AS internal_band,
--         id.dpd_category,
--         id.closing_principal
--     FROM loans l
--     JOIN instalment_delinquency id ON l.loan_id = id.loan_id
--     WHERE 
--         -- Limit to exactly Month 6
--         ((EXTRACT(YEAR FROM id.scheduled_instalment_date) - EXTRACT(YEAR FROM l.origination_date)) * 12 +
--          (EXTRACT(MONTH FROM id.scheduled_instalment_date) - EXTRACT(MONTH FROM l.origination_date))) = 6
--         -- Filter out "young" loans that haven't reached MOB 6 yet
--         AND l.origination_date <= (CURRENT_DATE - INTERVAL '6 months')
-- )
-- SELECT 
--     vintage,
--     bureau_band,
--     internal_band,
--     COUNT(loan_id) AS loan_count,
--     -- Calculate the % of principal that is "Bad" (30+ DPD or Written Off) at Month 6
--     ROUND(
--         SUM(CASE WHEN dpd_category IN ('dpd 30-59', 'dpd 60-89', 'dpd 90+', 'written off') THEN closing_principal ELSE 0 END)
--         / NULLIF(SUM(loan_amount), 0) * 100.0,
--         2
--     ) AS pct_bad_at_mob6
-- FROM mob6_snapshot
-- GROUP BY 1, 2, 3
-- ORDER BY 1 DESC, 2 ASC, 3 ASC;


WITH score_performance AS (
    SELECT 
        l.loan_id,
        l.internal_score,
        l.credit_bureau_score,
        l.loan_amount,
        -- Default Indicator: 1 if DPD 90+ or Written Off, else 0
        CASE 
            WHEN id.dpd_category IN ('dpd 90+', 'written off') THEN 1 
            ELSE 0 
        END AS is_default,
        id.closing_principal
    FROM loans l
    JOIN instalment_delinquency id ON l.loan_id = id.loan_id
    WHERE
        l.lender_id = $lender_id
        -- REMOVED: id.lender_id and id.year/month/day checks
        AND (
            l.year > $start_year OR
            (l.year = $start_year AND l.month > $start_month) OR
            (l.year = $start_year AND l.month = $start_month AND l.day >= $start_day)
        )
        AND (
            l.year < $end_year OR
            (l.year = $end_year AND l.month < $end_month) OR
            (l.year = $end_year AND l.month = $end_month AND l.day <= $end_day)
        )
        -- We usually evaluate "Power of Scores" at a specific maturity (e.g., MOB 6 or 12)
        -- or across all historical data available.
)
SELECT 
    -- Grouping by score deciles or buckets to see predictive power
    (internal_score / 10) * 10 AS internal_score_bucket,
    COUNT(loan_id) AS total_loans,
    SUM(is_default) AS total_defaults,
    ROUND(CAST(SUM(is_default) AS DOUBLE) / NULLIF(COUNT(loan_id), 0) * 100.0, 2) AS default_rate
FROM score_performance
GROUP BY 1
ORDER BY 1 DESC;
