#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.11: The Command Dispatcher."""
import os
import re
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
    script = workspace / "service_ctl.sh"
    pid_file = workspace / "service.pid"

    if not script.exists():
        fail("Missing required script: service_ctl.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"service_ctl.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit: verify case ... in ... esac
    log("Auditing case dispatcher structure in service_ctl.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    if not re.search(r'\bcase\s+.*\s+in\b', active_code) or "esac" not in active_code:
        fail("Missing required 'case ... in ... esac' command dispatcher construct.")

    # 1. Status when stopped
    log("Testing initial status check (should be STOPPED, exit 3)...")
    res1 = subprocess.run(["bash", str(script), "status"], cwd=str(workspace), capture_output=True, text=True)
    if res1.returncode != 3:
        fail(f"Expected exit code 3 when service is stopped, got {res1.returncode}. Output: {res1.stdout.strip()}")
    if "STOPPED" not in res1.stdout:
        fail(f"Expected 'STATUS: STOPPED', got: {res1.stdout.strip()}")

    # 2. Start service
    log("Testing 'start' command...")
    res2 = subprocess.run(["bash", str(script), "start"], cwd=str(workspace), capture_output=True, text=True)
    if res2.returncode != 0:
        fail(f"'start' failed with code {res2.returncode}: {res2.stderr.strip()}")
    if "SERVICE_STARTED" not in res2.stdout:
        fail("Missing 'SERVICE_STARTED' confirmation on start.")
    if not pid_file.exists():
        fail("service.pid was not created after start.")

    pid_str = pid_file.read_text(encoding="utf-8").strip()

    # 3. Status when running
    log(f"Testing 'status' when running (PID: {pid_str})...")
    res3 = subprocess.run(["bash", str(script), "status"], cwd=str(workspace), capture_output=True, text=True)
    if res3.returncode != 0:
        fail(f"Expected exit code 0 when running, got {res3.returncode}.")
    if "RUNNING" not in res3.stdout or pid_str not in res3.stdout:
        fail(f"Expected 'STATUS: RUNNING (pid={pid_str})', got: {res3.stdout.strip()}")

    # 4. Duplicate start prevention
    log("Testing duplicate 'start' prevention...")
    res4 = subprocess.run(["bash", str(script), "start"], cwd=str(workspace), capture_output=True, text=True)
    if res4.returncode == 0:
        fail("Duplicate 'start' should fail with exit code 1 when service is already running.")

    # 5. Stop service
    log("Testing 'stop' command...")
    res5 = subprocess.run(["bash", str(script), "stop"], cwd=str(workspace), capture_output=True, text=True)
    if res5.returncode != 0:
        fail(f"'stop' failed with code {res5.returncode}: {res5.stderr.strip()}")
    if "SERVICE_STOPPED" not in res5.stdout:
        fail("Missing 'SERVICE_STOPPED' confirmation on stop.")
    if pid_file.exists():
        fail("service.pid was not deleted after stop.")

    # 6. Status after stop
    res6 = subprocess.run(["bash", str(script), "status"], cwd=str(workspace), capture_output=True, text=True)
    if res6.returncode != 3:
        fail(f"Expected exit code 3 after stop, got {res6.returncode}.")

    # 7. Stale PID file handling
    log("Testing stale PID file detection and recovery...")
    pid_file.write_text("999999\n", encoding="utf-8")  # Dead PID
    res7 = subprocess.run(["bash", str(script), "status"], cwd=str(workspace), capture_output=True, text=True)
    if res7.returncode != 2:
        fail(f"Expected exit code 2 on stale PID file, got {res7.returncode}.")
    if "STALE_PID" not in res7.stdout:
        fail(f"Expected 'STATUS: STALE_PID' on dead PID, got: {res7.stdout.strip()}")

    # Start should recover from stale PID
    res8 = subprocess.run(["bash", str(script), "start"], cwd=str(workspace), capture_output=True, text=True)
    if res8.returncode != 0:
        fail("Start should automatically recover from stale PID file.")

    # Clean up background process
    subprocess.run(["bash", str(script), "stop"], cwd=str(workspace), capture_output=True, text=True)

    # 8. Help and Unknown commands
    log("Testing help flags (-h, --help, help)...")
    for h in ["-h", "--help", "help"]:
        res_h = subprocess.run(["bash", str(script), h], cwd=str(workspace), capture_output=True, text=True)
        if res_h.returncode != 0:
            fail(f"Help flag '{h}' should exit 0.")

    log("Testing wildcard catch-all for unknown command...")
    res_unk = subprocess.run(["bash", str(script), "invalid_command_xyz"], cwd=str(workspace), capture_output=True, text=True)
    if res_unk.returncode == 0:
        fail("Unknown command should exit with non-zero exit code 1.")

    log("Successfully verified command routing, PID lifecycle, stale recovery, and wildcard exit codes!")
    print("\n  [PASS] ALL COMMAND DISPATCHER ROUTES AND EXIT CODES VERIFIED.")


if __name__ == "__main__":
    main()
