from ..base import BaseMetrics
from .registry import CREDIT_METRICS

class CreditMetrics(BaseMetrics):
    def __init__(self, calculation):
        super().__init__(calculation, CREDIT_METRICS, "credit")
