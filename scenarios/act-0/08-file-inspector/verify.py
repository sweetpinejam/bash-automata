#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.08: The File Inspector."""
import json
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
    script = workspace / "preflight.sh"
    config_file = workspace / "config/app.conf"
    bin_file = workspace / "bin/app"
    symlink_file = workspace / "current_release"
    target_rel = workspace / "releases/v1.0"
    report_file = workspace / "health_report.json"

    if not script.exists():
        fail("Missing required script: preflight.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"preflight.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit for file test operators
    log("Auditing file test operators in preflight.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    for op in ["-s", "-d", "-x", "-L", "-e"]:
        if op not in active_code:
            fail(f"Missing required file test operator '{op}' in preflight.sh.")

    # Test 1: All healthy run
    log("Testing pre-flight execution on fully valid infrastructure...")
    res1 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res1.returncode != 0:
        fail(f"preflight.sh failed when all infrastructure is valid: {res1.stderr.strip()}")
    if "ALL_CHECKS_PASSED" not in res1.stdout:
        fail("preflight.sh did not print 'ALL_CHECKS_PASSED' on clean environment.")
    if not report_file.exists():
        fail("Missing required 'health_report.json' report file.")

    try:
        report = json.loads(report_file.read_text(encoding="utf-8"))
    except Exception as e:
        fail(f"Invalid JSON in health_report.json: {e}")

    if report.get("status") != "PASSED" or report.get("failed_checks") != 0 or report.get("passed_checks") != 5:
        fail(f"Unexpected health report metrics: {report}")

    # Test 2: Zero-byte empty config file (-s test)
    log("Testing zero-byte config file detection (-s)...")
    config_file.write_text("", encoding="utf-8")
    res2 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res2.returncode == 0:
        fail("preflight.sh must exit 1 when config file is empty (zero bytes).")
    if "config_integrity" not in res2.stdout and "config_integrity" not in res2.stderr:
        fail("preflight.sh did not report 'config_integrity' failure.")

    # Restore config
    config_file.write_text("port=8080 mode=production\n", encoding="utf-8")

    # Test 3: Binary missing execute permission (-x test)
    log("Testing non-executable binary detection (-x)...")
    bin_file.chmod(0o644)
    res3 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res3.returncode == 0:
        fail("preflight.sh must exit 1 when bin/app lacks execute permissions.")
    if "binary_executable" not in res3.stdout and "binary_executable" not in res3.stderr:
        fail("preflight.sh did not report 'binary_executable' failure.")

    # Restore binary permissions
    bin_file.chmod(0o755)

    # Test 4: Dangling symlink detection (-L && -e)
    log("Testing dangling symlink detection (-L && -e)...")
    target_rel.rmdir()  # Target is deleted, current_release is now dangling!
    res4 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res4.returncode == 0:
        fail("preflight.sh must exit 1 when current_release is a dangling symlink.")
    if "symlink_integrity" not in res4.stdout and "symlink_integrity" not in res4.stderr:
        fail("preflight.sh did not report 'symlink_integrity' failure on dangling link.")

    # Restore symlink target
    target_rel.mkdir(parents=True, exist_ok=True)

    # Test 5: Custom report path
    log("Testing --report CLI flag...")
    custom_report = workspace / "custom_audit.json"
    res5 = subprocess.run(
        ["bash", str(script), "--report", str(custom_report)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res5.returncode != 0:
        fail(f"preflight.sh failed with custom report argument: {res5.stderr.strip()}")
    if not custom_report.exists():
        fail("Custom report file 'custom_audit.json' was not generated.")

    log("Successfully verified all file operators (-s, -d, -x, -L, -e) and diagnostic reporting!")
    print("\n  [PASS] ALL FILE TESTS (-s, -d, -x) VERIFIED ACROSS POSITIVE AND NEGATIVE SCENARIOS.")


if __name__ == "__main__":
    main()
