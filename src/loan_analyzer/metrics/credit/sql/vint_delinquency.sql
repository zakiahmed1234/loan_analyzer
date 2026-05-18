WITH mob_base AS (
    SELECT
        l.loan_id,
        CAST(DATE_TRUNC('month', CAST(l.origination_date AS DATE)) AS DATE) AS vintage,
        l.loan_amount AS original_principal,
        -- Athena specific Month diff
        date_diff('month',
                  CAST(l.origination_date AS DATE),
                  CAST(id.scheduled_instalment_date AS DATE)
        ) AS mob,
        id.dpd_category,
        id.closing_principal
    FROM loans l
    JOIN instalment_delinquency id ON l.loan_id = id.loan_id
    WHERE
        l.lender_id = $lender_id
        -- Removed id.lender_id and id.year/month/day checks 
        -- because they don't exist in the temporary 'id' table schema.
        AND id.closing_principal > 0
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
)
SELECT
    vintage,
    mob,
    ROUND(SUM(CASE WHEN dpd_category = 'current' THEN closing_principal ELSE 0 END) / NULLIF(SUM(original_principal), 0) * 100.0, 2) AS pct_current,
    ROUND(SUM(CASE WHEN dpd_category = 'dpd 1-29' THEN closing_principal ELSE 0 END) / NULLIF(SUM(original_principal), 0) * 100.0, 2) AS pct_1_29,
    ROUND(SUM(CASE WHEN dpd_category = 'dpd 30-59' THEN closing_principal ELSE 0 END) / NULLIF(SUM(original_principal), 0) * 100.0, 2) AS pct_30_59,
    ROUND(SUM(CASE WHEN dpd_category = 'dpd 60-89' THEN closing_principal ELSE 0 END) / NULLIF(SUM(original_principal), 0) * 100.0, 2) AS pct_60_89,
    ROUND(SUM(CASE WHEN dpd_category = 'dpd 90+' THEN closing_principal ELSE 0 END) / NULLIF(SUM(original_principal), 0) * 100.0, 2) AS pct_90_plus,
    ROUND(SUM(CASE WHEN dpd_category = 'written off' THEN closing_principal ELSE 0 END) / NULLIF(SUM(original_principal), 0) * 100.0, 2) AS pct_write_off
FROM mob_base
WHERE mob >= 0
GROUP BY 1, 2
ORDER BY 1 DESC, 2 ASC
