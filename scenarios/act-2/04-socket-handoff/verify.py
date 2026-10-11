#!/usr/bin/env python3
"""State assertion test for Mission 2.04: The Unix Socket Handoff."""
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
    ctl_sh = workspace / "service_ctl.sh"
    sock_file = workspace / "daemon.sock"
    client_py = workspace / "client.py"

    if not ctl_sh.exists():
        fail("Missing required script: service_ctl.sh")

    # TEST 1: Smooth restart & immediate client connectivity
    log("Test 1: Executing 'service_ctl.sh restart'...")
    proc_restart = subprocess.run(
        ["bash", str(ctl_sh), "restart"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )

    if proc_restart.returncode != 0:
        fail(f"service_ctl.sh restart failed (exit code {proc_restart.returncode}).\nStderr: {proc_restart.stderr.strip()}")

    if "RESTART_COMPLETE" not in proc_restart.stdout:
        fail("service_ctl.sh restart did not output 'RESTART_COMPLETE'.")

    log("Auditing immediate client connection over Unix socket...")
    proc_client = subprocess.run(
        ["python3", str(client_py)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=3,
    )

    if proc_client.returncode != 0:
        fail(f"Client failed to connect immediately after restart!\nStderr: {proc_client.stderr.strip()}")

    if "PONG_OK" not in proc_client.stdout:
        fail("Client connected but did not receive PONG_OK.")

    # TEST 2: Status check
    log("Test 2: Verifying 'service_ctl.sh status'...")
    proc_status = subprocess.run(
        ["bash", str(ctl_sh), "status"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=3,
    )
    if "STATUS_RUNNING" not in proc_status.stdout:
        fail(f"service_ctl.sh status expected 'STATUS_RUNNING', got:\n{proc_status.stdout}")

    # TEST 3: Stale socket recovery (simulate ungraceful crash)
    log("Test 3: Simulating crash with stale daemon.sock on disk...")
    # Stop daemon
    subprocess.run(["bash", str(ctl_sh), "stop"], cwd=str(workspace), capture_output=True)
    # Inject stale socket file
    sock_file.write_text("STALE_CRASH_DATA", encoding="utf-8")

    proc_recover = subprocess.run(
        ["bash", str(ctl_sh), "start"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )

    if proc_recover.returncode != 0:
        fail(f"service_ctl.sh failed to start when stale socket existed on disk!\nStderr: {proc_recover.stderr.strip()}")

    proc_client2 = subprocess.run(
        ["python3", str(client_py)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=3,
    )

    if proc_client2.returncode != 0 or "PONG_OK" not in proc_client2.stdout:
        fail("Client failed to communicate after recovery from stale socket!")

    # Teardown
    subprocess.run(["bash", str(ctl_sh), "stop"], cwd=str(workspace), capture_output=True)

    log("ALL UNIX DOMAIN SOCKET ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
