#!/usr/bin/env python3
"""State assertion test for Mission 2.03: The Flaking Healthcheck Latch."""
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
    checker_sh = workspace / "canary_checker.sh"
    counter_file = workspace / "probe_counter.txt"

    if not checker_sh.exists():
        fail("Missing required script: canary_checker.sh")

    # TEST 1: Transient Fault Resistance
    log("Test 1: Simulating transient network blips (intermittent drops)...")
    if counter_file.exists():
        counter_file.unlink()

    env_transient = os.environ.copy()
    env_transient["PROBE_MODE"] = "transient"

    proc1 = subprocess.run(
        ["bash", str(checker_sh)],
        cwd=str(workspace),
        env=env_transient,
        capture_output=True,
        text=True,
        timeout=5,
    )

    if proc1.returncode != 0:
        fail(f"Test 1 failed! Canary prematurely aborted on transient blips (exit code {proc1.returncode}).\nStderr: {proc1.stderr.strip()}")

    if "CANARY_HEALTHY" not in proc1.stdout:
        fail("Test 1 failed! Script completed but did not output 'CANARY_HEALTHY'.")

    # Verify all 10 cycles executed
    cycles_run = 0
    if counter_file.exists():
        try:
            cycles_run = int(counter_file.read_text(encoding="utf-8").strip())
        except Exception:
            pass

    log(f"Test 1 completed all {cycles_run}/10 cycles successfully.")
    if cycles_run != 10:
        fail(f"Expected 10 probe cycles executed, but found {cycles_run}.")

    # TEST 2: True Persistent Outage Detection
    log("Test 2: Simulating true service outage (persistent 500s)...")
    if counter_file.exists():
        counter_file.unlink()

    env_outage = os.environ.copy()
    env_outage["PROBE_MODE"] = "outage"

    proc2 = subprocess.run(
        ["bash", str(checker_sh)],
        cwd=str(workspace),
        env=env_outage,
        capture_output=True,
        text=True,
        timeout=5,
    )

    if proc2.returncode == 0:
        fail("Test 2 failed! Canary checker reported success during an active outage! Should exit code 1.")

    if "CANARY_ABORTED" not in proc2.stdout and "CANARY_ABORTED" not in proc2.stderr:
        fail("Test 2 failed! Script failed without emitting 'CANARY_ABORTED'.")

    outage_cycles = 0
    if counter_file.exists():
        try:
            outage_cycles = int(counter_file.read_text(encoding="utf-8").strip())
        except Exception:
            pass

    log(f"Test 2 aborted at cycle {outage_cycles} (Threshold: 3 consecutive failures).")
    if outage_cycles != 3:
        fail(f"Expected outage to trigger abort at exactly 3 consecutive failures, but reached cycle {outage_cycles}.")

    log("ALL HEALTHCHECK LATCH ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
