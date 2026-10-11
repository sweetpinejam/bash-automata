#!/usr/bin/env python3
"""State-driven verification for Drill 0.16: The Defensive Shield."""
import json
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
    deploy_sh = workspace / "deploy.sh"

    if not deploy_sh.exists():
        fail("Missing required script: deploy.sh")

    content = deploy_sh.read_text(encoding="utf-8")
    code_lines = [l for l in content.splitlines() if not l.strip().startswith("#")]
    active_code = "\n".join(code_lines)

    log("Auditing static defensive structures in deploy.sh...")

    # 1. Check defensive flags
    has_pipefail = "pipefail" in active_code
    has_errexit = "set -e" in active_code or "-e" in active_code
    has_nounset = "set -u" in active_code or "-u" in active_code

    if not (has_pipefail and (has_errexit or "set -euo pipefail" in active_code)):
        fail("deploy.sh must declare 'set -euo pipefail' (or equivalent defensive flags).")

    # 2. Check ERR trap and on_failure
    if "on_failure" not in active_code:
        fail("deploy.sh must define an 'on_failure' function to record crash diagnostics.")
    if "trap" not in active_code or "ERR" not in active_code:
        fail("deploy.sh must register a trap for 'ERR' signal.")

    # -------------------------------------------------------------------------
    # Test 1: Normal Execution
    # -------------------------------------------------------------------------
    log("Testing standard deployment execution (DEPLOY_ENV=production, RELEASE_TAG=v1.4.2)...")
    status_file = workspace / "deploy_status.json"
    crash_file = workspace / "deploy_crash.dump"
    status_file.unlink(missing_ok=True)
    crash_file.unlink(missing_ok=True)

    env = dict(os.environ)
    env["DEPLOY_ENV"] = "production"
    env["RELEASE_TAG"] = "v1.4.2"

    res = subprocess.run(
        ["bash", str(deploy_sh)],
        cwd=str(workspace),
        env=env,
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res.returncode != 0:
        fail(f"deploy.sh failed standard execution with exit code {res.returncode}.\nStderr: {res.stderr}")

    if not status_file.exists():
        fail("deploy.sh did not generate 'deploy_status.json' on successful deployment.")

    try:
        data = json.loads(status_file.read_text(encoding="utf-8"))
        if data.get("status") != "SUCCESS":
            fail(f"Expected status 'SUCCESS' in deploy_status.json, got: {data.get('status')}")
        if data.get("environment") != "production":
            fail(f"Expected environment 'production' in deploy_status.json, got: {data.get('environment')}")
        if data.get("tag") != "v1.4.2":
            fail(f"Expected tag 'v1.4.2' in deploy_status.json, got: {data.get('tag')}")
    except json.JSONDecodeError as exc:
        fail(f"Failed to parse deploy_status.json as JSON: {exc}")

    if "DEPLOY_HARDENED" not in res.stdout:
        fail("Expected standard log output starting with 'DEPLOY_HARDENED:'.")

    # -------------------------------------------------------------------------
    # Test 2: Unbound Variable Enforcement (set -u)
    # -------------------------------------------------------------------------
    log("Testing nounset defense (unbound variable assertion)...")
    status_file.unlink(missing_ok=True)
    crash_file.unlink(missing_ok=True)

    # Isolated clean environment with no DEPLOY_ENV or RELEASE_TAG
    clean_env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin")}
    res_unbound = subprocess.run(
        ["bash", str(deploy_sh)],
        cwd=str(workspace),
        env=clean_env,
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res_unbound.returncode == 0:
        fail("deploy.sh succeeded when executed with unbound variables! 'set -u' must abort execution.")

    if "unbound variable" not in res_unbound.stderr.lower():
        fail(f"Expected 'unbound variable' error from bash nounset check. Got stderr:\n{res_unbound.stderr}")

    if status_file.exists():
        fail("deploy_status.json was created despite unbound variable error.")

    # -------------------------------------------------------------------------
    # Test 3: Pipeline Failure Detection (set -o pipefail + ERR Trap)
    # -------------------------------------------------------------------------
    log("Testing pipeline failure detection (set -o pipefail + ERR trap)...")
    status_file.unlink(missing_ok=True)
    crash_file.unlink(missing_ok=True)

    res_pipe = subprocess.run(
        ["bash", str(deploy_sh), "staging", "v2.0.0", "--simulate-pipe-fail"],
        cwd=str(workspace),
        env=env,
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res_pipe.returncode == 0:
        fail("deploy.sh did not fail when an upstream command in a pipeline crashed! 'pipefail' is not working.")

    if not crash_file.exists():
        fail("ERR trap did not generate 'deploy_crash.dump' when pipeline failure occurred.")

    dump_content = crash_file.read_text(encoding="utf-8")
    if "CRASH_LINE=" not in dump_content or "FAILED_COMMAND=" not in dump_content:
        fail(f"deploy_crash.dump is missing required diagnostic fields. Got:\n{dump_content}")

    # -------------------------------------------------------------------------
    # Test 4: Command Crash Detection (set -e + ERR Trap)
    # -------------------------------------------------------------------------
    log("Testing command failure detection (set -e + ERR trap)...")
    status_file.unlink(missing_ok=True)
    crash_file.unlink(missing_ok=True)

    res_crash = subprocess.run(
        ["bash", str(deploy_sh), "canary", "v3.0.0", "--simulate-crash"],
        cwd=str(workspace),
        env=env,
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res_crash.returncode == 0:
        fail("deploy.sh did not fail when critical step failed! 'set -e' must abort execution.")

    if not crash_file.exists():
        fail("ERR trap did not generate 'deploy_crash.dump' when command crash occurred.")

    log("Defensive shield, nounset, pipefail, and ERR crash diagnostics successfully verified!")
    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
