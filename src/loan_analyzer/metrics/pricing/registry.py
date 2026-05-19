PRICING_METRICS = {
    "fee_yield": {
        "sql": "fee_per_amount_over_time.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.fee_per_amount_over_time"
    },
    "interest_vintage": {
        "sql": "interest_over_vintage.sql"
    },
    "pricing_risk": {
        "sql": "pricing_over_risk.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.pricing_over_risk"
    },
    "yield_curve": {
        "sql": "yield_curve_evolution.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.yield_curve_evolution"
    }
}
