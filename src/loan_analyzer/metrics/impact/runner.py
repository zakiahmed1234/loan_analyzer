from ..base import BaseMetrics
from .registry import IMPACT_METRICS

class ImpactMetrics(BaseMetrics):
    def __init__(self, calculation):
        super().__init__(calculation, IMPACT_METRICS, "impact")
