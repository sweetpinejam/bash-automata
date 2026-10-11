#!/usr/bin/env python3
"""State assertion test for Mission 2.10: The Graceful Drain Teardown."""
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
    service_sh = workspace / "worker_service.sh"
    commit_file = workspace / "transactions.commit"
    drain_file = workspace / "drain.log"
    pid_file = workspace / "worker.pid"

    if not service_sh.exists():
        fail("Missing required script: worker_service.sh")

    if commit_file.exists():
        commit_file.unlink()
    if drain_file.exists():
        drain_file.unlink()
    if pid_file.exists():
        pid_file.unlink()

    log("Launching worker_service in background...")
    proc = subprocess.Popen(
        ["bash", str(service_sh)],
        cwd=str(workspace),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    # Wait for PID file
    for _ in range(20):
        if pid_file.exists():
            break
        time.sleep(0.05)

    if not pid_file.exists():
        proc.kill()
        fail("worker.pid was not created by worker_service.sh!")

    worker_pid = int(pid_file.read_text(encoding="utf-8").strip())
    log(f"Worker running with PID {worker_pid}. Processing transactions...")

    # Allow worker to process 1-2 jobs, and interrupt mid-flight during job 2 or 3
    time.sleep(0.18)

    log("Sending SIGTERM to simulate container drain / rollout eviction...")
    try:
        os.kill(worker_pid, signal.SIGTERM)
    except OSError as e:
        fail(f"Failed to send SIGTERM to worker PID: {e}")

    # Wait for process to cleanly terminate
    try:
        stdout, stderr = proc.communicate(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()
        fail("Worker failed to terminate within 3s after receiving SIGTERM (hung drain)!")

    log(f"Worker exited with return code: {proc.returncode}")

    if proc.returncode != 0:
        fail(f"Worker did not exit cleanly with code 0 on SIGTERM! Return code: {proc.returncode}.\nStderr: {stderr.strip()}")

    log("Auditing transaction integrity in transactions.commit...")
    if not commit_file.exists():
        fail("transactions.commit file not found!")

    lines = [l.strip() for l in commit_file.read_text(encoding="utf-8").splitlines() if l.strip()]
    starts = [l.split(": ")[1] for l in lines if l.startswith("TX_START:")]
    commits = [l.split(": ")[1] for l in lines if l.startswith("TX_COMMITTED:")]

    log(f"Transactions started: {starts}")
    log(f"Transactions committed: {commits}")

    if not starts or not commits:
        fail("No transactions were processed before termination!")

    # Check for torn transactions: every started transaction MUST be committed
    if starts != commits:
        uncommitted = set(starts) - set(commits)
        fail(f"Data corruption detected! Uncommitted in-flight transactions were severed: {uncommitted}")

    log("Auditing drain verification in drain.log...")
    if not drain_file.exists():
        fail("drain.log not created by worker service!")

    drain_content = drain_file.read_text(encoding="utf-8").strip()
    if "DRAIN_COMPLETED" not in drain_content:
        fail(f"drain.log missing 'DRAIN_COMPLETED' marker! Found: '{drain_content}'")

    log("ALL GRACEFUL DRAIN ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
