#!/usr/bin/env python3
"""State-driven verification for Drill 0.17: The Exit Trap."""
import glob
import json
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


def check_no_leaks(workspace: Path, context: str):
    sandboxes = list(workspace.glob(".sandbox_*"))
    pid_file = workspace / "active_job.pid"

    if sandboxes:
        fail(f"[{context}] Leaked transient sandbox directories on disk: {[str(s.name) for s in sandboxes]}")
    if pid_file.exists():
        fail(f"[{context}] Leaked active_job.pid on disk!")


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    job_sh = workspace / "job.sh"
    manifest_file = workspace / "job_manifest.json"

    if not job_sh.exists():
        fail("Missing required script: job.sh")

    content = job_sh.read_text(encoding="utf-8")
    code_lines = [l for l in content.splitlines() if not l.strip().startswith("#")]
    active_code = "\n".join(code_lines)

    log("Auditing static trap and cleanup definitions in job.sh...")
    if "trap " not in active_code:
        fail("job.sh must declare a signal trap using 'trap ...'.")
    if "cleanup" not in active_code:
        fail("job.sh must define a 'cleanup' function.")
    if "EXIT" not in active_code:
        fail("job.sh must trap the 'EXIT' pseudo-signal.")

    # -------------------------------------------------------------------------
    # Test 1: Normal Execution
    # -------------------------------------------------------------------------
    log("Test 1: Executing standard run...")
    for s in workspace.glob(".sandbox_*"):
        if s.is_dir():
            import shutil
            shutil.rmtree(s)
    (workspace / "active_job.pid").unlink(missing_ok=True)
    manifest_file.unlink(missing_ok=True)

    res = subprocess.run(
        ["bash", str(job_sh)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res.returncode != 0:
        fail(f"job.sh failed under normal execution ({res.returncode}):\n{res.stderr}")

    if not manifest_file.exists():
        fail("job.sh did not produce 'job_manifest.json' on normal execution.")

    try:
        data = json.loads(manifest_file.read_text(encoding="utf-8"))
        if data.get("status") != "SUCCESS":
            fail(f"Expected status 'SUCCESS' in job_manifest.json, got: {data.get('status')}")
    except json.JSONDecodeError as exc:
        fail(f"Failed to parse job_manifest.json as JSON: {exc}")

    check_no_leaks(workspace, "Normal Execution")
    log("Normal run completed cleanly with zero disk leaks.")

    # -------------------------------------------------------------------------
    # Test 2: Crash Termination (--simulate-crash)
    # -------------------------------------------------------------------------
    log("Test 2: Stress testing error crash cleanup (--simulate-crash)...")
    manifest_file.unlink(missing_ok=True)

    res_crash = subprocess.run(
        ["bash", str(job_sh), "--simulate-crash"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res_crash.returncode == 0:
        fail("job.sh unexpectedly exited 0 during --simulate-crash test.")

    check_no_leaks(workspace, "Crash Termination")
    log("Exit trap successfully wiped sandbox and PID lock during crash failure.")

    # -------------------------------------------------------------------------
    # Test 3: External Signal Termination (SIGTERM)
    # -------------------------------------------------------------------------
    log("Test 3: Stress testing external signal termination (SIGTERM injection)...")
    manifest_file.unlink(missing_ok=True)

    proc = subprocess.Popen(
        ["bash", str(job_sh), "--hold"],
        cwd=str(workspace),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    # Wait for sandbox and PID file to appear
    acquired = False
    for _ in range(30):
        time.sleep(0.1)
        sandboxes = list(workspace.glob(".sandbox_*"))
        pid_file = workspace / "active_job.pid"
        if sandboxes and pid_file.exists():
            acquired = True
            break

    if not acquired:
        proc.kill()
        fail("job.sh did not provision scratch sandbox and PID file in time.")

    # Send SIGTERM to simulate orchestrator shutdown / pod termination
    try:
        proc.send_signal(signal.SIGTERM)
        proc.wait(timeout=5)
    except Exception as exc:
        proc.kill()
        fail(f"Signal handling test error: {exc}")

    check_no_leaks(workspace, "SIGTERM Termination")
    log("Exit and signal trap successfully wiped resources under external SIGTERM.")

    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
