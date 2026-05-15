-- setup_validation.sql
-- Initializes the table used to store invariant check results

CREATE OR REPLACE TABLE validation_results (
    check_name VARCHAR,
    passed BOOLEAN,
    details VARCHAR,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
