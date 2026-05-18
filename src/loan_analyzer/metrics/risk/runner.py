from ..base import BaseMetrics
from .registry import RISK_METRICS

class RiskMetrics(BaseMetrics):
    def __init__(self, calculation):
        super().__init__(calculation, RISK_METRICS, "risk")
