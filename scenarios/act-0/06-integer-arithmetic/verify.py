#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.06: Integer Arithmetic."""
import os
import re
import subprocess
import sys
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "aggregator.sh"
    log_file = workspace / "samples.log"
    rollup_file = workspace / "metrics_rollup.tsv"

    if not script.exists():
        fail("Missing required script: aggregator.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"aggregator.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit: strictly no external tools for arithmetic
    log("Auditing pure shell in-memory arithmetic in aggregator.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    for banned in ["expr", "bc", "awk", "dc", "python", "perl"]:
        if re.search(r"\b" + re.escape(banned) + r"\b", active_code):
            fail(f"Prohibited external command '{banned}' detected. Use native arithmetic '((' and '$((' instead.")

    if "((" not in active_code and "$((" not in active_code:
        fail("Missing native Bash arithmetic syntax: '((' or '$(('.")

    # Test 1: Standard dataset evaluation
    log("Executing aggregator on seeded traffic samples...")
    res = subprocess.run(
        ["bash", str(script), str(log_file)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"aggregator.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "AGGREGATOR_SUMMARY:" not in res.stdout:
        fail("aggregator.sh did not emit expected 'AGGREGATOR_SUMMARY:' summary.")

    if not rollup_file.exists():
        fail("Missing output file: metrics_rollup.tsv")

    # Parse rollup TSV
    rollup_data = {}
    for line in rollup_file.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split("\t")
        if len(parts) == 2:
            rollup_data[parts[0]] = parts[1]

    expected_metrics = {
        "TOTAL_REQS": "10",
        "COUNT_2XX": "6",
        "COUNT_3XX": "1",
        "COUNT_4XX": "2",
        "COUNT_5XX": "1",
        "AVG_LATENCY": "119",
        "MIN_LATENCY": "15",
        "MAX_LATENCY": "450",
        "TOTAL_BYTES": "6208",
        "SLA_COMPLIANCE": "90",
        "ERROR_PERCENT": "10",
        "SLA_VERDICT": "SLA_BREACH_HIGH_ERRORS",
    }

    for k, v in expected_metrics.items():
        if k not in rollup_data:
            fail(f"Missing metric '{k}' in metrics_rollup.tsv.")
        if rollup_data[k] != v:
            fail(f"Incorrect metric '{k}': expected '{v}', got '{rollup_data[k]}'")

    # Test 2: Latency breach dataset
    log("Testing SLA_BREACH_HIGH_LATENCY verdict branch...")
    high_latency_log = workspace / "high_lat.log"
    high_latency_log.write_text(
        "ts=1 m=GET status=200 latency_ms=350 size_bytes=100\n"
        "ts=2 m=GET status=200 latency_ms=400 size_bytes=100\n",
        encoding="utf-8",
    )
    res_lat = subprocess.run(
        ["bash", str(script), str(high_latency_log)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=3,
    )
    if res_lat.returncode != 0:
        fail(f"aggregator.sh failed on high latency test: {res_lat.stderr.strip()}")
    if "SLA_BREACH_HIGH_LATENCY" not in res_lat.stdout:
        fail(f"Expected 'SLA_BREACH_HIGH_LATENCY' for avg_latency=375ms. Got: {res_lat.stdout.strip()}")

    log("Successfully verified pure integer arithmetic, C-style operators, and SLA calculations!")
    print("\n  [PASS] NATIVE INTEGER ARITHMETIC FULLY VERIFIED.")


if __name__ == "__main__":
    main()
