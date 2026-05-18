from ..base import BaseMetrics
from .registry import PRICING_METRICS

class PricingMetrics(BaseMetrics):
    def __init__(self, calculation):
        super().__init__(calculation, PRICING_METRICS, "pricing")
