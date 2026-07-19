#!/usr/bin/env python3
"""Evaluate canary telemetry and decide whether to promote or roll back."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

DEFAULT_THRESHOLDS = {
    "availability_min": 99.9,
    "error_rate_max": 1.0,
    "p95_latency_ms_max": 500,
}


def evaluate(metrics: dict[str, float], thresholds: dict[str, float] | None = None) -> dict:
    limits = thresholds or DEFAULT_THRESHOLDS
    checks = {
        "availability": metrics["availability"] >= limits["availability_min"],
        "error_rate": metrics["error_rate"] <= limits["error_rate_max"],
        "p95_latency_ms": metrics["p95_latency_ms"] <= limits["p95_latency_ms_max"],
    }
    failed = [name for name, passed in checks.items() if not passed]
    return {
        "decision": "promote" if not failed else "rollback",
        "failed_signals": failed,
        "checks": checks,
        "metrics": metrics,
        "thresholds": limits,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--expect", choices=("promote", "rollback"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    scenarios = json.loads(args.input.read_text(encoding="utf-8"))
    if args.scenario not in scenarios:
        parser.error(f"unknown scenario: {args.scenario}")

    report = evaluate(scenarios[args.scenario])
    rendered = json.dumps(report, indent=2, sort_keys=True)
    print(rendered)

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")

    if args.expect and report["decision"] != args.expect:
        print(
            f"Expected {args.expect}, received {report['decision']}",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
