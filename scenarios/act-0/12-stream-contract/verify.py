#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.12: The Stream Contract."""
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
    script = workspace / "triage.sh"
    clean_log = workspace / "clean_payloads.log"
    err_log = workspace / "error_diagnostics.log"
    report_file = workspace / "stream_triage_report.json"

    if not script.exists():
        fail("Missing required script: triage.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"triage.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit for stream redirection operators
    log("Auditing file descriptor redirection operators in triage.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    if "2>" not in active_code:
        fail("Missing standard error redirection operator '2>'.")
    if ">" not in active_code:
        fail("Missing standard output redirection operator '>'.")

    # Test 1: Standard stream separation execution
    log("Testing stream demuxing execution...")
    res1 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res1.returncode != 0:
        fail(f"triage.sh failed with exit code {res1.returncode}. Stderr: {res1.stderr.strip()}")

    if "TRIAGE_COMPLETE:" not in res1.stdout:
        fail("triage.sh did not emit expected 'TRIAGE_COMPLETE:' summary.")

    if not clean_log.exists():
        fail("Missing clean payloads output file: clean_payloads.log")
    if not err_log.exists():
        fail("Missing error diagnostics output file: error_diagnostics.log")

    clean_lines = clean_log.read_text(encoding="utf-8").splitlines()
    err_lines = err_log.read_text(encoding="utf-8").splitlines()

    # Verify zero cross-contamination
    log("Auditing stream cross-contamination defense...")
    for l in clean_lines:
        if "ERROR:" in l:
            fail(f"Cross-contamination breach: Error diagnostic found in clean payload log: '{l}'")
    for l in err_lines:
        if "DATA:" in l:
            fail(f"Cross-contamination breach: Payload data found in error diagnostic log: '{l}'")

    if len(clean_lines) != 3:
        fail(f"Expected 3 clean payload lines, got {len(clean_lines)}.")
    if len(err_lines) != 3:
        fail(f"Expected 3 error diagnostic lines, got {len(err_lines)}.")

    # Validate stream_triage_report.json
    log("Validating stream_triage_report.json report metrics...")
    if not report_file.exists():
        fail("Missing required report file: stream_triage_report.json")

    try:
        report = json.loads(report_file.read_text(encoding="utf-8"))
    except Exception as e:
        fail(f"Invalid JSON in stream_triage_report.json: {e}")

    if report.get("status") != "TRIAGED":
        fail(f"Expected status 'TRIAGED', got: {report.get('status')}")
    if report.get("payload_lines") != 3:
        fail(f"Expected payload_lines=3, got: {report.get('payload_lines')}")
    if report.get("error_lines") != 3:
        fail(f"Expected error_lines=3, got: {report.get('error_lines')}")
    if report.get("cross_contamination") is not False:
        fail("Expected cross_contamination=false in report.")

    # Test 2: Custom log paths
    log("Testing custom log file destinations...")
    c_out = workspace / "custom_clean.log"
    c_err = workspace / "custom_error.log"
    res2 = subprocess.run(
        ["bash", str(script), "--stdout-log", str(c_out), "--stderr-log", str(c_err)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res2.returncode != 0:
        fail(f"triage.sh failed with custom log paths: {res2.stderr.strip()}")
    if not c_out.exists() or not c_err.exists():
        fail("Custom log files were not created.")

    log("Successfully verified stream separation, FD 1/2 routing, and JSON reporting!")
    print("\n  [PASS] POSIX STREAM REDIRECTION CONTRACT FULLY VERIFIED.")


if __name__ == "__main__":
    main()
