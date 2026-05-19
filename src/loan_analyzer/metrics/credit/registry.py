CREDIT_METRICS = {
    "credit_profiles": {
        "sql": "credit_profiles.sql"
    },
    "grade_dist": {
        "sql": "grade_dist.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.grade_dist"
    },
    "loan_interval": {
        "sql": "loan_interval.sql"
    },
    "score_prog": {
        "sql": "score_prog.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.score_prog"
    },
    "transition_matrix": {
        "sql": "trans_prob.sql"
    },
    "vintage_delinquency": {
        "sql": "vint_delinquency.sql",
        "graph": "loan_analyzer.core.loan_system.graphs.ChartFactory.vintage_dpd_trend"
    },
    "vintage_yield": {
        "sql": "vint_yield.sql"
    }
}
