IMPACT_METRICS = {
    "loan_use": {
        "sql": "loan_use_monthly.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.loan_use_monthly"
    },
    "location": {
        "sql": "location_monthly.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.location_monthly"
    },
    "monthly_lended": {
        "sql": "monthly_lended.sql"
    },
    "borrower_delta": {
        "sql": "unique_borrower_delta.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.unique_borrower_delta"
    }
}
