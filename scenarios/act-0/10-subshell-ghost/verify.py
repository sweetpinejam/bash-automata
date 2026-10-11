#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.10: The Subshell Ghost."""
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
    script = workspace / "auditor.sh"
    ledger_file = workspace / "ledger.csv"
    report_file = workspace / "audit_report.tsv"
    fraud_file = workspace / "fraud_alerts.log"

    if not script.exists():
        fail("Missing required script: auditor.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"auditor.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit: strictly no pipe into while loop
    log("Auditing subshell prevention and process substitution in auditor.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    if re.search(r'\|\s*while\b', active_code):
        fail("Pipeline into while loop detected ('| while'). Pipelines execute loops in a subshell, destroying variable mutations.")

    if "< <(" not in active_code and "<<<" not in active_code and "< <" not in active_code:
        fail("Missing process substitution construct ('< <(command)').")

    # Execute auditor.sh
    log("Executing financial ledger auditor...")
    res = subprocess.run(
        ["bash", str(script), str(ledger_file), str(report_file)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"auditor.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "AUDIT_COMPLETE:" not in res.stdout:
        fail("auditor.sh did not emit expected 'AUDIT_COMPLETE:' summary.")

    if not report_file.exists():
        fail("Audit report 'audit_report.tsv' was not created.")

    # Validate audit TSV metrics
    report_data = {}
    for l in report_file.read_text(encoding="utf-8").splitlines():
        parts = l.strip().split("\t")
        if len(parts) == 2:
            report_data[parts[0]] = parts[1]

    expected_metrics = {
        "TOTAL_TX": "7",
        "TOTAL_CREDITS": "13200",
        "TOTAL_DEBITS": "6800",
        "NET_BALANCE": "6400",
        "FLAGGED_FRAUD": "1",
        "ACCOUNTS_TRACKED": "3",
    }

    for k, exp in expected_metrics.items():
        if k not in report_data:
            fail(f"Missing metric '{k}' in audit_report.tsv.")
        if report_data[k] != exp:
            fail(f"Incorrect metric '{k}': expected '{exp}', got '{report_data[k]}'")

    # Validate fraud log
    if not fraud_file.exists():
        fail("Missing required 'fraud_alerts.log' file.")

    fraud_content = fraud_file.read_text(encoding="utf-8")
    if "tx=TX105" not in fraud_content or "account=ACC_02" not in fraud_content or "amount=6000" not in fraud_content:
        fail(f"Fraud transaction TX105 not properly recorded in fraud_alerts.log. Content: {fraud_content.strip()}")

    log("Successfully verified process substitution, variable survival in main shell, and fraud alerting!")
    print("\n  [PASS] PROCESS SUBSTITUTION & SUBSHELL DEFENSE VERIFIED SUCCESSFULLY.")


if __name__ == "__main__":
    main()
