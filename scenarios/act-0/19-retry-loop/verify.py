#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.19: The Exponential Backoff Retry Loop."""
import os
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
    script = workspace / "probe.sh"
    mock_service = workspace / "mock_service.sh"
    counter_tmp = Path("/tmp/mock_service_call_count.tmp")

    if not script.exists():
        fail("Missing required script: probe.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing retry loop and exponential backoff syntax...")
    if "while " not in active_code:
        fail("Missing 'while' loop construct for retries.")

    if "sleep " not in active_code:
        fail("Missing 'sleep' command between retry attempts (danger: busy-wait CPU storm).")

    if "*=" not in active_code and "* 2" not in active_code:
        fail("Missing exponential backoff multiplier (e.g., '(( delay *= 2 ))').")

    def run_probe():
        return subprocess.run(
            ["bash", str(script)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )

    # 2. Test successful recovery on attempt 3
    log("Test 1: Testing recovery of transiently failing service (succeeds attempt 3)...")
    if counter_tmp.exists():
        counter_tmp.unlink()

    res1 = run_probe()
    if res1.returncode != 0:
        fail(f"probe.sh failed to recover transient service. Exit code {res1.returncode}. Stderr: {res1.stderr.strip()}")

    if "SERVICE_READY" not in res1.stdout:
        fail("Expected 'SERVICE_READY' in output.")

    calls = int(counter_tmp.read_text(encoding="utf-8").strip()) if counter_tmp.exists() else 0
    if calls != 3:
        fail(f"Expected service to be probed exactly 3 times before succeeding, got {calls} attempts.")
    log(f"Service successfully polled {calls} times with exponential backoff before reporting ready.")

    # 3. Test timeout on persistent failure
    log("Test 2: Testing timeout when service fails permanently...")
    mock_service.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
    res2 = run_probe()
    if res2.returncode == 0:
        fail("probe.sh succeeded when service permanently failed! Must abort with exit code 1.")

    if "PROBE_TIMEOUT" not in res2.stderr and "PROBE_TIMEOUT" not in res2.stdout:
        fail("Expected 'PROBE_TIMEOUT' warning on persistent failure.")

    # Cleanup
    if counter_tmp.exists():
        counter_tmp.unlink()

    log("Verified exponential backoff retry loop and timeout bounds.")
    print("\n  [PASS] EXPONENTIAL BACKOFF RETRY PROBE VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
