#!/usr/bin/env python3
"""State-driven verification for Drill 0.1: The Stream Contract."""
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
    triage_sh = workspace / "triage.sh"
    clean_log = workspace / "clean.log"
    error_log = workspace / "error.log"

    if not triage_sh.exists():
        fail("Missing required script: triage.sh")

    # Clean existing logs prior to execution
    if clean_log.exists():
        clean_log.unlink()
    if error_log.exists():
        error_log.unlink()

    log("Executing triage.sh in workspace...")
    try:
        res = subprocess.run(
            ["bash", str(triage_sh)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception as e:
        fail(f"Execution failed: {e}")

    if res.returncode != 0:
        fail(f"triage.sh failed with exit code {res.returncode}. Stderr: {res.stderr}")

    log("Auditing generated log destinations...")
    if not clean_log.exists():
        fail("clean.log was not created. Did you redirect stdout using '> clean.log'?")
    if not error_log.exists():
        fail("error.log was not created. Did you redirect stderr using '2> error.log'?")

    clean_content = clean_log.read_text(encoding="utf-8").strip()
    error_content = error_log.read_text(encoding="utf-8").strip()

    if not clean_content:
        fail("clean.log is empty. Expected DATA lines.")
    if not error_content:
        fail("error.log is empty. Expected ERROR lines.")

    # Cross contamination check
    if "ERROR:" in clean_content:
        fail("clean.log contains stderr ERROR lines! Only stdout data should be present.")
    if "DATA:" in error_content:
        fail("error.log contains stdout DATA lines! Only stderr errors should be present.")

    log(f"clean.log: {len(clean_content.splitlines())} valid data entries.")
    log(f"error.log: {len(error_content.splitlines())} valid error entries.")
    log("All stream redirection contracts satisfied.")
    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
