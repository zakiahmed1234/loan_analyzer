RISK_METRICS = {
    "status_distribution": {
        "sql": "status_distribution.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.status_distribution"
    },
    "defaults": {
        "sql": "defaults.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.defaults"
    },
    "lgd": {
        "sql": "loss_given_default.sql"
    },
    "instalment_delinquency": {
        "sql": "instalment_delinquency_maker.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.instalment_delinquency"
    },
    "score_power": {
        "sql": "power_of_scores.sql"
    },
    "prepayments_writeoffs": {
        "sql": "prepayments_writeoffs_penalties.sql"
    }
}
