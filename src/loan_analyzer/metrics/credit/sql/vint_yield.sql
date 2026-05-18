WITH yield_metrics AS (
    SELECT
        l.loan_id,
        CAST(DATE_TRUNC('month', CAST(l.origination_date AS DATE)) AS DATE) AS vintage,
        -- MOB calculation using date_diff
        date_diff('month',
                  CAST(l.origination_date AS DATE),
                  CAST(ls.period_start AS DATE)
        ) AS mob,
        ls.opening_principal,
        ls.interest_accrued,
        ls.cash_received,
        ls.write_off_occurred,
        LEAST(CAST(ls.interest_accrued AS DOUBLE), CAST(ls.cash_received AS DOUBLE)) AS interest_collected
    FROM loans l
    JOIN loan_state ls ON l.loan_id = ls.loan_id
    WHERE
        l.lender_id = ${lender_id}
        AND ls.lender_id = ${lender_id}
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
        AND (
            ls.year > ${start_year} OR
            (ls.year = ${start_year} AND ls.month > ${start_month}) OR
            (ls.year = ${start_year} AND ls.month = ${start_month} AND ls.day >= ${start_day})
        )
        AND (
            ls.year < ${end_year} OR
            (ls.year = ${end_year} AND ls.month < ${end_month}) OR
            (ls.year = ${end_year} AND ls.month = ${end_month} AND ls.day <= ${end_day})
        )
)
SELECT
    vintage,
    mob,
    -- Gross Yield
    ROUND(SUM(interest_collected) / NULLIF(SUM(CAST(opening_principal AS DOUBLE)), 0) * 12 * 100.0, 2) AS annualized_gross_yield_pct,
    -- Net Yield
    ROUND(SUM(interest_collected - write_off_occurred) / NULLIF(SUM(CAST(opening_principal AS DOUBLE)), 0) * 12 * 100.0, 2) AS annualized_net_yield_pct,
    SUM(opening_principal) AS total_active_principal
FROM yield_metrics
WHERE mob >= 0
GROUP BY 1, 2
ORDER BY 1 DESC, 2 ASC
