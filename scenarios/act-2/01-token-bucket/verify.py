#!/usr/bin/env python3
"""State assertion test for Mission 2.01: The Token Bucket Semaphore."""
import json
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
    dispatcher_sh = workspace / "dispatcher.sh"
    state_file = workspace / "api_state.json"
    log_file = workspace / "api.log"

    if not dispatcher_sh.exists():
        fail("Missing required script: dispatcher.sh")

    # Clean previous run state
    if state_file.exists():
        state_file.unlink()
    if log_file.exists():
        log_file.unlink()

    log("Executing dispatcher under load (16 concurrent jobs)...")
    try:
        proc = subprocess.run(
            ["bash", str(dispatcher_sh)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=10,
        )
    except subprocess.TimeoutExpired:
        fail("dispatcher.sh timed out (>10s) — possible deadlock on semaphore tokens!")
    except Exception as e:
        fail(f"Execution error: {e}")

    if proc.returncode != 0:
        fail(f"dispatcher.sh exited with error code {proc.returncode}.\nStderr: {proc.stderr.strip()}")

    if "DISPATCH_COMPLETE" not in proc.stdout:
        fail("dispatcher.sh did not complete cleanly or emit 'DISPATCH_COMPLETE'.")

    log("Auditing concurrency telemetry from API telemetry ledger...")
    if not state_file.exists():
        fail("No telemetry state recorded by mock API.")

    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
    except Exception as e:
        fail(f"Failed to parse API state ledger: {e}")

    max_observed = state.get("max_observed", 0)
    breaches = state.get("breaches", 0)
    processed_count = len(state.get("processed", []))

    log(f"Peak concurrency observed: {max_observed} (Max allowed: 4)")
    log(f"HTTP 429 rate limit breaches: {breaches}")
    log(f"Total jobs successfully processed: {processed_count}/16")

    if breaches > 0:
        fail(f"Detected {breaches} HTTP 429 rate limit breaches! Concurrency exceeded 4.")

    if max_observed > 4:
        fail(f"Peak concurrency {max_observed} exceeded limit 4.")

    if processed_count != 16:
        fail(f"Expected 16 processed jobs, but only {processed_count} completed.")

    log("ALL CONCURRENCY ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
