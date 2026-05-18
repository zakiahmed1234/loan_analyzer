/* In this we describe how a borrowers credit numbers change over time. Specifically, each borrower has a certain number of loans attached to him. Each of these loans has a specific date of origination, and internal and bureau credit scores. We organise these loans chronologically by origination date and track the change in scores over time for each borrower */



WITH RankedLoans AS (
    -- Step 1: Sequence every loan for every borrower chronologically
    SELECT
        borrower_id,
        loan_id,
        origination_date,
        credit_bureau_score,
        internal_score,
        -- This creates a "Loan Number" for each borrower (1st loan, 2nd loan, etc.)
        ROW_NUMBER() OVER (
            PARTITION BY borrower_id
            ORDER BY origination_date ASC
        ) as loan_sequence_number
    -- Explicitly filter the LOANS table inside a subquery to satisfy Partition Projection
    FROM (
        SELECT * FROM loans 
        WHERE lender_id = ${lender_id} -- Force static equality (Python provides quotes)
        AND (
            (year > ${start_year}) OR 
            (year = ${start_year} AND month > ${start_month}) OR 
            (year = ${start_year} AND month = ${start_month} AND day >= ${start_day})
        )
        AND (
            (year < ${end_year}) OR 
            (year = ${end_year} AND month < ${end_month}) OR 
            (year = ${end_year} AND month = ${end_month} AND day <= ${end_day})
        )
    ) l 
),
ScoreChanges AS (
    -- Step 2: Compare current scores to the previous loan's scores
    SELECT
        borrower_id,
        loan_id,
        origination_date,
        loan_sequence_number,
        credit_bureau_score,
        internal_score,
        -- Get the score from the immediately preceding loan
        LAG(credit_bureau_score) OVER (PARTITION BY borrower_id ORDER BY loan_sequence_number) as prev_bureau_score,
        LAG(internal_score) OVER (PARTITION BY borrower_id ORDER BY loan_sequence_number) as prev_internal_score
    FROM RankedLoans
)
-- Step 3: Calculate the delta (the improvement or decline)
SELECT
    borrower_id,
    loan_sequence_number,
    origination_date,
    credit_bureau_score,
    internal_score,
    -- Calculate the improvement
    (credit_bureau_score - prev_bureau_score) as bureau_score_delta,
    (internal_score - prev_internal_score) as internal_score_delta
FROM ScoreChanges
ORDER BY borrower_id, loan_sequence_number;
