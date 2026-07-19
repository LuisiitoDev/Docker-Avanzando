import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("evaluate_canary.py")
SPEC = importlib.util.spec_from_file_location("evaluate_canary", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)


class CanaryGateTests(unittest.TestCase):
    def test_healthy_metrics_are_promoted(self):
        report = MODULE.evaluate(
            {"availability": 99.99, "error_rate": 0.2, "p95_latency_ms": 240}
        )
        self.assertEqual("promote", report["decision"])
        self.assertEqual([], report["failed_signals"])

    def test_any_failed_signal_rolls_back(self):
        report = MODULE.evaluate(
            {"availability": 99.95, "error_rate": 1.2, "p95_latency_ms": 300}
        )
        self.assertEqual("rollback", report["decision"])
        self.assertEqual(["error_rate"], report["failed_signals"])

    def test_threshold_boundary_is_accepted(self):
        report = MODULE.evaluate(
            {"availability": 99.9, "error_rate": 1.0, "p95_latency_ms": 500}
        )
        self.assertEqual("promote", report["decision"])


if __name__ == "__main__":
    unittest.main()
