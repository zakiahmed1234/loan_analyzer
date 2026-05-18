/* This records default rates. In particular, for a specific origination month, we look at the proportion of loans that defaulted on each month on the books, and then range over origination months */

--
-- SELECT 
--     l.loan_id,
--     TRIM(l.loan_status) AS status_check,
--     DATE_TRUNC('month', CAST(l.origination_date AS DATE)) AS vintage,
--     -- Handle loans with NO payments using LEFT JOIN + COALESCE
--     COALESCE(
--         ((EXTRACT(YEAR FROM ap.last_pay) - EXTRACT(YEAR FROM l.origination_date)) * 12 +
--          (EXTRACT(MONTH FROM ap.last_pay) - EXTRACT(MONTH FROM l.origination_date))),
--         -3
--     ) + 3 AS deduced_default_mob
-- FROM loans l
-- LEFT JOIN (
--     SELECT loan_id, MAX(actual_payment_date) AS last_pay
--     FROM actual_payments
--     GROUP BY 1
-- ) ap ON l.loan_id = ap.loan_id
-- -- Use ILIKE to be case-insensitive and catch partial matches
-- WHERE l.loan_status ILIKE '%default%'
-- ORDER BY 4 ASC;

SELECT 
    l.loan_id,
    TRIM(l.loan_status) AS status_check,
    DATE_TRUNC('month', CAST(l.origination_date AS DATE)) AS vintage,
    COALESCE(
        date_diff(
            'month', 
            CAST(l.origination_date AS DATE), 
            CAST(ap.last_pay AS DATE)
        ), 
        -3
    ) + 3 AS deduced_default_mob
FROM loans l
LEFT JOIN (
    SELECT
        loan_id,
        MAX(CAST(actual_payment_date AS DATE)) AS last_pay
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
) ap ON l.loan_id = ap.loan_id
-- Standard Presto/Athena v2 Case-Insensitive Filter
WHERE
    l.lender_id = ${lender_id}
    AND LOWER(l.loan_status) LIKE '%default%'
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
ORDER BY 4 ASC;
