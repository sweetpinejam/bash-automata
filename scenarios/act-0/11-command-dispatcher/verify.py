#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.11: The Command Dispatcher."""
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
    script = workspace / "service_ctl.sh"
    pid_file = workspace / "service.pid"

    if not script.exists():
        fail("Missing required script: service_ctl.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing case ... in ... esac dispatcher syntax...")
    if "case " not in active_code or "esac" not in active_code:
        fail("Missing 'case ... in ... esac' construct.")

    if ";;" not in active_code:
        fail("Missing branch terminator ';;'")

    if "*)" not in active_code:
        fail("Missing fallback catch-all pattern '*)'")

    def run_cmd(arg: str):
        return subprocess.run(
            ["bash", str(script), arg],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )

    # 2. Test lifecycle: start -> status -> stop -> status
    log("Test 1: Starting service ('start')...")
    res_start = run_cmd("start")
    if res_start.returncode != 0:
        fail(f"'start' failed with exit code {res_start.returncode}. Stderr: {res_start.stderr.strip()}")
    if "SERVICE_STARTED" not in res_start.stdout:
        fail("Expected 'SERVICE_STARTED' in output.")
    if not pid_file.exists():
        fail("Expected 'service.pid' to be created upon start.")

    log("Test 2: Querying status when running ('status')...")
    res_stat1 = run_cmd("status")
    if res_stat1.returncode != 0:
        fail(f"'status' failed with exit code {res_stat1.returncode}")
    if "STATUS_RUNNING" not in res_stat1.stdout:
        fail(f"Expected 'STATUS_RUNNING', got: '{res_stat1.stdout.strip()}'")

    log("Test 3: Stopping service ('stop')...")
    res_stop = run_cmd("stop")
    if res_stop.returncode != 0:
        fail(f"'stop' failed with exit code {res_stop.returncode}")
    if "SERVICE_STOPPED" not in res_stop.stdout:
        fail("Expected 'SERVICE_STOPPED' in output.")
    if pid_file.exists():
        fail("Expected 'service.pid' to be removed upon stop.")

    log("Test 4: Querying status when stopped ('status')...")
    res_stat2 = run_cmd("status")
    if res_stat2.returncode != 0:
        fail(f"'status' failed with exit code {res_stat2.returncode}")
    if "STATUS_STOPPED" not in res_stat2.stdout:
        fail(f"Expected 'STATUS_STOPPED', got: '{res_stat2.stdout.strip()}'")

    # 3. Test help flags
    log("Test 5: Checking grouped help flags ('--help' and '-h')...")
    for h in ["--help", "-h", "help"]:
        res_h = run_cmd(h)
        if res_h.returncode != 0 or "USAGE:" not in res_h.stdout:
            fail(f"Help flag '{h}' failed or did not print usage information.")

    # 4. Test invalid action
    log("Test 6: Checking fallback catch-all ('*) on invalid action...")
    res_invalid = run_cmd("bogus_command")
    if res_invalid.returncode == 0:
        fail("Invalid action succeeded with exit code 0! Must terminate with exit code 1.")

    print("\n  [PASS] ALL COMMAND DISPATCHER ROUTES AND EXIT CODES VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
