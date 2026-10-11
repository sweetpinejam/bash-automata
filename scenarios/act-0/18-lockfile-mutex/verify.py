#!/usr/bin/env python3
"""State-driven verification for Drill 0.18: The Lockfile Mutex."""
import json
import os
import shutil
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
    script = workspace / "worker.sh"
    lock_dir = workspace / "sync.lock"
    summary_file = workspace / "sync_summary.json"

    if not script.exists():
        fail("Missing required script: worker.sh")

    content = script.read_text(encoding="utf-8")
    code_lines = [l for l in content.splitlines() if not l.strip().startswith("#")]
    active_code = "\n".join(code_lines)

    log("Auditing atomic mutex declarations in worker.sh...")
    if "mkdir -p" in active_code:
        fail("Prohibited 'mkdir -p' detected for mutex! 'mkdir -p' suppresses EEXIST, destroying atomicity.")
    if "mkdir " not in active_code:
        fail("Missing atomic 'mkdir' lock command in active code.")
    if "kill -0" not in active_code and "kill " not in active_code:
        fail("Missing PID liveness check ('kill -0 $pid') for stale lock detection.")
    if "trap " not in active_code or "EXIT" not in active_code:
        fail("Missing 'trap ... EXIT' declaration to release lock.")

    # -------------------------------------------------------------------------
    # Test 1: Uncontested Worker Execution
    # -------------------------------------------------------------------------
    log("Test 1: Running uncontested worker execution...")
    if lock_dir.exists():
        shutil.rmtree(lock_dir)
    summary_file.unlink(missing_ok=True)

    res1 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res1.returncode != 0:
        fail(f"worker.sh failed on uncontested run ({res1.returncode}). Stderr:\n{res1.stderr}")

    if "MUTEX_WORKER" not in res1.stdout:
        fail("Expected summary log starting with 'MUTEX_WORKER:' in stdout.")

    if not summary_file.exists():
        fail("worker.sh did not produce 'sync_summary.json'.")

    try:
        data = json.loads(summary_file.read_text(encoding="utf-8"))
        if data.get("status") != "SUCCESS":
            fail(f"Expected status 'SUCCESS' in summary, got: {data.get('status')}")
        if data.get("events_processed") != 5:
            fail(f"Expected 5 events processed, got: {data.get('events_processed')}")
        if data.get("total_amount") != 400:
            fail(f"Expected total_amount 400, got: {data.get('total_amount')}")
    except json.JSONDecodeError as exc:
        fail(f"Failed to parse sync_summary.json as JSON: {exc}")

    if lock_dir.exists():
        fail("Lock directory 'sync.lock' leaked on disk! Ensure EXIT trap removes it.")

    log("Uncontested execution processed events and unlocked cleanly.")

    # -------------------------------------------------------------------------
    # Test 2: Active Lock Collision & Rejection
    # -------------------------------------------------------------------------
    log("Test 2: Stress testing active lock collision...")
    summary_file.unlink(missing_ok=True)

    # Spawn first worker holding lock for 3s
    holder = subprocess.Popen(
        ["bash", str(script), "--hold"],
        cwd=str(workspace),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    # Wait for holder to acquire lock
    acquired = False
    for _ in range(25):
        time.sleep(0.1)
        if lock_dir.exists() and (lock_dir / "pid").exists():
            acquired = True
            break

    if not acquired:
        holder.kill()
        fail("Background holder worker failed to create sync.lock within 2.5s.")

    # Attempt second worker run while lock is held
    res2 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )

    if res2.returncode == 0:
        holder.kill()
        fail("Second worker succeeded while lock was actively held! Mutual exclusion violated.")

    combined_output = res2.stdout + res2.stderr
    if "LOCK_ACQUIRE_FAILED" not in combined_output:
        holder.kill()
        fail(f"Expected 'LOCK_ACQUIRE_FAILED' when lock is contested. Got output:\n{combined_output}")

    # Wait for holder to finish
    holder.wait(timeout=5)
    if lock_dir.exists():
        fail("Holder worker leaked lock directory after completing execution.")

    log("Active lock collision rejected second worker and released cleanly upon holder completion.")

    # -------------------------------------------------------------------------
    # Test 3: Stale Lock Detection & Self-Healing Reclaim
    # -------------------------------------------------------------------------
    log("Test 3: Stress testing stale lock recovery (dead PID simulation)...")
    summary_file.unlink(missing_ok=True)

    # Fabricate a stale lock with a dead PID (999999)
    lock_dir.mkdir(parents=True, exist_ok=True)
    (lock_dir / "pid").write_text("999999\n", encoding="utf-8")

    res3 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res3.returncode != 0:
        fail(f"worker.sh failed to recover from stale lock ({res3.returncode}). Stderr:\n{res3.stderr}")

    if not summary_file.exists():
        fail("worker.sh did not complete work after reclaiming stale lock.")

    if lock_dir.exists():
        fail("Lock directory leaked on disk after stale lock recovery execution.")

    log("Stale lock successfully detected, reclaimed, and cleaned up.")
    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
