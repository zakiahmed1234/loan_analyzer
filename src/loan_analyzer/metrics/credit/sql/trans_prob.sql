/* In this we calculate transition probabilities between different states over time. Specifically, we calculate P(state_t = i | state_(t-1) = j and some context) where
STATE = {Current, dpd 30, dpd 60, dpd 90+, paid off, defaulted} and context can represent some control, like borrower type or vintage. We then sort our probabilities over each month. */


WITH MonthlyStates AS (
    SELECT
        id.loan_id,
        CAST(DATE_TRUNC('month', CAST(l.origination_date AS DATE)) AS DATE) AS vintage,
        date_diff('month',
                  CAST(l.origination_date AS DATE),
                  CAST(id.scheduled_instalment_date AS DATE)
        ) AS mob,
        CASE
            WHEN l.loan_status = 'PaidOff' THEN 'Paid Off'
            WHEN l.loan_status = 'Defaulted' THEN 'Defaulted'
            WHEN l.loan_status = 'WrittenOff' THEN 'Written Off'
            WHEN l.loan_status = 'Canceled' THEN 'Canceled'
            WHEN id.days_past_due >= 90 THEN 'DPD 90+'
            WHEN id.days_past_due >= 60 THEN 'DPD 60-89'
            WHEN id.days_past_due >= 30 THEN 'DPD 30-59'
            WHEN id.days_past_due > 0  THEN 'DPD 1-29'
            ELSE 'Current'
        END AS state_label
    FROM instalment_delinquency id
    JOIN loans l ON id.loan_id = l.loan_id
    WHERE
        l.lender_id = ${lender_id}
        -- We only filter on 'l' (loans) because 'id' is already pre-filtered 
        -- and doesn't contain these column names in its schema.
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
Transitions AS (
    SELECT
        vintage,
        mob,
        state_label AS current_state,
        LEAD(state_label) OVER (PARTITION BY loan_id ORDER BY mob) AS future_state
    FROM MonthlyStates
),
TransitionCounts AS (
    SELECT
        vintage,
        mob,
        current_state,
        future_state,
        COUNT(*) as transition_count
    FROM Transitions
    WHERE future_state IS NOT NULL
      AND current_state NOT IN ('Paid Off', 'Defaulted', 'Written Off', 'Canceled')
    GROUP BY 1, 2, 3, 4
)
SELECT
    vintage,
    mob,
    current_state,
    future_state,
    transition_count,
    ROUND(
        100.0 * transition_count / SUM(transition_count) OVER (PARTITION BY vintage, mob, current_state),
        2
    ) AS transition_prob
FROM TransitionCounts
ORDER BY 1 DESC, 2 ASC, 3, 4 DESC
