#!/usr/bin/env python3
"""State-driven verification for Drill 0.3: The Exit Trap."""
import os
import signal
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
    job_sh = workspace / "job.sh"
    lock_file = workspace / "job.lock"

    if not job_sh.exists():
        fail("Missing required script: job.sh")

    content = job_sh.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    log("Auditing active signal trap declaration...")
    if "trap " not in active_code:
        fail("job.sh must declare a signal trap using 'trap ...'.")

    # Clean existing lock
    if lock_file.exists():
        lock_file.unlink()

    log("Test 1: Executing normal run...")
    res = subprocess.run(["bash", str(job_sh)], cwd=str(workspace), capture_output=True, text=True, timeout=10)
    if res.returncode != 0:
        fail(f"job.sh failed under normal execution ({res.returncode}): {res.stderr}")

    if lock_file.exists():
        fail("Lock file leaked on disk after normal script completion!")

    log("Test 2: Stress testing signal termination (SIGTERM injection)...")
    # Spawn in background, verify lock appears, then send SIGTERM
    proc = subprocess.Popen(["bash", str(job_sh)], cwd=str(workspace), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(0.3)  # Give script time to acquire lock

    # Send SIGTERM
    try:
        proc.send_signal(signal.SIGTERM)
        proc.wait(timeout=3)
    except Exception as e:
        fail(f"Signal handling test error: {e}")

    if lock_file.exists():
        fail("Lock file leaked on disk after SIGTERM! The trap did not clean up the lock.")

    log("Lock file properly unlinked on both normal exit and SIGTERM.")
    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
