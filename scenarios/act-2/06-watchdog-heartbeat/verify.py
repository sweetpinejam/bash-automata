#!/usr/bin/env python3
"""State assertion test for Mission 2.06: The Self-Healing Watchdog Heartbeat."""
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


def is_pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    watchdog_sh = workspace / "watchdog.sh"
    pid_file = workspace / "worker.pid"
    hb_file = workspace / "heartbeat.ts"

    if not watchdog_sh.exists():
        fail("Missing required script: watchdog.sh")

    if not pid_file.exists():
        fail("Initial worker.pid not staged.")

    try:
        frozen_pid = int(pid_file.read_text(encoding="utf-8").strip())
    except Exception as e:
        fail(f"Failed to read frozen PID: {e}")

    log(f"Auditing frozen worker (PID: {frozen_pid}). Initial liveness: {is_pid_alive(frozen_pid)}")

    log("Executing self-healing watchdog...")
    # Provide TRIGGER_FREEZE=false during respawn so new worker stays healthy
    env = os.environ.copy()
    env["TRIGGER_FREEZE"] = "false"

    proc = subprocess.run(
        ["bash", str(watchdog_sh)],
        cwd=str(workspace),
        env=env,
        capture_output=True,
        text=True,
        timeout=5,
    )

    if proc.returncode != 0:
        fail(f"watchdog.sh failed (exit code {proc.returncode}).\nStderr: {proc.stderr.strip()}")

    if "WORKER_RESPAWNED" not in proc.stdout:
        fail("watchdog.sh did not detect staleness or output 'WORKER_RESPAWNED'.")

    log("Verifying termination of frozen PID...")
    time.sleep(0.1)
    if is_pid_alive(frozen_pid):
        fail(f"Frozen PID {frozen_pid} is still alive! Watchdog failed to terminate the stuck process.")

    log("Auditing newly respawned worker...")
    if not pid_file.exists():
        fail("New worker.pid not found after respawn.")

    try:
        new_pid = int(pid_file.read_text(encoding="utf-8").strip())
    except Exception as e:
        fail(f"Failed to read new PID: {e}")

    if new_pid == frozen_pid:
        fail("Worker PID did not change after watchdog execution!")

    if not is_pid_alive(new_pid):
        fail(f"Newly spawned PID {new_pid} is not running.")

    log("Waiting for fresh heartbeats from new worker...")
    time.sleep(0.2)
    now = int(time.time())
    last_hb = int(hb_file.read_text(encoding="utf-8").strip())
    staleness = now - last_hb
    log(f"New worker heartbeat staleness: {staleness}s (Now: {now}, HB: {last_hb})")

    if staleness > 2:
        fail(f"New worker is not updating heartbeat.ts! Staleness is {staleness}s.")

    # Cleanup spawned worker
    try:
        os.kill(new_pid, 9)
    except OSError:
        pass

    log("ALL SELF-HEALING WATCHDOG ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
