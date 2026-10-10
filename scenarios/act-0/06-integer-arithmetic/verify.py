#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.06: Integer Arithmetic."""
import os
import subprocess
import sys
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def parse_summary(path: Path) -> dict:
    if not path.exists():
        return {}
    res = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            res[k.strip()] = v.strip()
    return res


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "aggregator.sh"
    summary_file = workspace / "summary.txt"

    if not script.exists():
        fail("Missing required script: aggregator.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing pure shell arithmetic syntax...")
    for banned in ["expr", "bc", "awk", "python"]:
        if banned in active_code:
            fail(f"Prohibited external arithmetic command '{banned}' detected. Use native '(( ... ))' and '$(( ... ))'.")

    if "((" not in active_code:
        fail("Missing native arithmetic evaluation '(( ... ))'")

    if "$((" not in active_code:
        fail("Missing native arithmetic expansion '$(( ... ))'")

    # 2. Execution
    log("Executing metrics aggregator...")
    res = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"aggregator.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "METRICS_AGGREGATED" not in res.stdout:
        fail("aggregator.sh did not complete cleanly.")

    # 3. Check summary.txt
    log("Validating aggregated calculation accuracy...")
    if not summary_file.exists():
        fail("Summary file 'summary.txt' was not created.")

    data = parse_summary(summary_file)
    if data.get("TOTAL_COUNT") != "5":
        fail(f"Expected TOTAL_COUNT=5, got '{data.get('TOTAL_COUNT')}'")
    if data.get("AVG_LATENCY") != "80":
        fail(f"Expected AVG_LATENCY=80, got '{data.get('AVG_LATENCY')}' (400ms / 5 requests)")
    if data.get("ERR_PCT") != "40":
        fail(f"Expected ERR_PCT=40, got '{data.get('ERR_PCT')}' (2 errors / 5 requests * 100)")

    log("Calculations verified: TOTAL_COUNT=5, AVG_LATENCY=80ms, ERR_PCT=40%.")
    print("\n  [PASS] ALL METRIC CALCULATIONS ACCURATE WITH ZERO SUBPROCESS FORKS.")
    sys.exit(0)


if __name__ == "__main__":
    main()
