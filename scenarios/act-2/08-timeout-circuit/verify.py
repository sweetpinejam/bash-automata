#!/usr/bin/env python3
"""State assertion test for Mission 2.08: The Cascading Timeout Shield."""
import os
import subprocess
import sys
import time
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    caller_sh = workspace / "gateway_caller.sh"

    if not caller_sh.exists():
        fail("Missing required script: gateway_caller.sh")

    # TEST 1: Normal fast execution
    log("Test 1: Executing fast upstream RPC call...")
    proc_fast = subprocess.run(
        ["bash", str(caller_sh), "normal"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=3,
    )

    if proc_fast.returncode != 0:
        fail(f"Test 1 failed on normal call (exit code {proc_fast.returncode}).\nStderr: {proc_fast.stderr.strip()}")

    if "CALL_SUCCESSFUL" not in proc_fast.stdout:
        fail("Test 1 did not emit 'CALL_SUCCESSFUL'.")

    # TEST 2: Hanging call with timeout interruption
    log("Test 2: Executing hanging upstream RPC call (Simulating hang)...")
    t0 = time.monotonic()
    try:
        proc_hang = subprocess.run(
            ["bash", str(caller_sh), "hang"],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=2.5,
        )
    except subprocess.TimeoutExpired:
        fail("Test 2 timed out (>2.5s)! gateway_caller.sh failed to interrupt the hanging subprocess.")
    duration = time.monotonic() - t0

    log(f"Hanging call interrupted in {duration:.2f}s (Expected: ~1.0s - 1.8s)")

    if duration > 2.5:
        fail(f"Timeout took too long ({duration:.2f}s)! Target timeout is ~1 second.")

    if proc_hang.returncode == 0:
        fail("Test 2 reported success on a hanging process! Expected non-zero timeout exit code (e.g. 124).")

    if "TIMEOUT_INTERRUPTED" not in proc_hang.stdout and "TIMEOUT_INTERRUPTED" not in proc_hang.stderr:
        fail("gateway_caller.sh did not report 'TIMEOUT_INTERRUPTED'.")

    # Verify no orphan python3 upstream_rpc process
    ps_proc = subprocess.run(["pgrep", "-f", "upstream_rpc.py"], capture_output=True, text=True)
    if ps_proc.stdout.strip():
        # Kill stray process
        subprocess.run(["pkill", "-9", "-f", "upstream_rpc.py"])
        fail("Orphan process leak! The hanging upstream_rpc.py process was not killed upon timeout.")

    log("ALL TIMEOUT CIRCUIT ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
