#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.18: The Lockfile Mutex."""
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
    script = workspace / "worker.sh"
    lock_dir = workspace / "sync.lock"

    if not script.exists():
        fail("Missing required script: worker.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing atomic mutex locking in worker.sh...")
    if "mkdir -p" in active_code:
        fail("Prohibited 'mkdir -p' detected for mutex! 'mkdir -p' succeeds even if directory exists, destroying atomicity.")

    if "mkdir " not in active_code:
        fail("Missing atomic 'mkdir' lock command.")

    if "trap " not in active_code or "EXIT" not in active_code:
        fail("Missing 'trap ... EXIT' declaration to release lock.")

    def run_worker():
        return subprocess.run(
            ["bash", str(script)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )

    # 2. Test uncontested lock run
    log("Test 1: Running uncontested worker execution...")
    if lock_dir.exists():
        lock_dir.rmdir()

    res1 = run_worker()
    if res1.returncode != 0:
        fail(f"worker.sh failed on uncontested run with exit code {res1.returncode}. Stderr: {res1.stderr.strip()}")

    if "SYNC_SUCCESS" not in res1.stdout:
        fail("Expected 'SYNC_SUCCESS' in output.")

    if lock_dir.exists():
        fail("Lock directory 'sync.lock' was not cleaned up after execution! Ensure EXIT trap removes it.")

    # 3. Test mutual exclusion collision
    log("Test 2: Simulating active lock collision...")
    lock_dir.mkdir()

    res2 = run_worker()
    if res2.returncode == 0:
        fail("Worker succeeded when lock was already held! It must abort immediately.")

    if "LOCK_ACQUIRE_FAILED" not in res2.stdout:
        fail(f"Expected 'LOCK_ACQUIRE_FAILED' when lock exists. Got: {res2.stdout.strip()}")

    # Cleanup
    if lock_dir.exists():
        lock_dir.rmdir()

    log("Verified atomic lock acquisition, mutual exclusion rejection, and automatic EXIT cleanup.")
    print("\n  [PASS] ATOMIC MUTEX VIA MKDIR AND EXIT TRAP VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
