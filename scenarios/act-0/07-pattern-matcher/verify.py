#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.07: Pattern Matcher."""
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
    script = workspace / "classifier.sh"
    log_file = workspace / "firewall.log"
    out_csv = workspace / "threats.csv"

    if not script.exists():
        fail("Missing required script: classifier.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"classifier.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit: strictly no external tools for text extraction
    log("Auditing pure shell in-memory regex matching in classifier.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    for banned in ["grep", "awk", "cut", "sed", "python", "perl"]:
        if re.search(r"\b" + re.escape(banned) + r"\b", active_code):
            fail(f"Prohibited external command '{banned}' detected. Use native '=~' and 'BASH_REMATCH'.")

    if "=~" not in active_code:
        fail("Missing native Bash regex matching operator '=~'.")
    if "BASH_REMATCH" not in active_code:
        fail("Missing native Bash capture group array 'BASH_REMATCH'.")

    # Run classifier
    log("Executing pure in-memory security threat classifier...")
    res = subprocess.run(
        ["bash", str(script), str(log_file), str(out_csv)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"classifier.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "CLASSIFIER_SUMMARY:" not in res.stdout:
        fail("classifier.sh did not emit expected 'CLASSIFIER_SUMMARY:' summary.")

    if not out_csv.exists():
        fail("Output file 'threats.csv' was not created.")

    # Validate CSV records
    log("Validating threats.csv format and threat classifications...")
    lines = [l.strip() for l in out_csv.read_text(encoding="utf-8").splitlines() if l.strip()]
    if len(lines) != 6:
        fail(f"Expected 6 lines in threats.csv (1 header + 5 threats), found {len(lines)}.")

    header = lines[0]
    if header != "TIMESTAMP,IP,PORT,SEVERITY,REASON,SCOPE":
        fail(f"Invalid CSV header. Expected 'TIMESTAMP,IP,PORT,SEVERITY,REASON,SCOPE', got: '{header}'")

    expected_rows = [
        "1700000001,192.168.1.100,443,CRITICAL,SQL_INJECTION,INTERNAL",
        "1700000003,45.33.32.156,22,HIGH,BRUTE_FORCE_AUTH,EXTERNAL",
        "1700000005,198.51.100.22,8080,CRITICAL,REMOTE_CODE_EXEC,EXTERNAL",
        "1700000006,10.2.1.80,3306,MEDIUM,UNAUTHORIZED_ACCESS,INTERNAL",
        "1700000007,203.0.113.88,80,HIGH,PORT_SCAN,EXTERNAL",
    ]

    for expected in expected_rows:
        if expected not in lines[1:]:
            fail(f"Missing or mismatched threat record in threats.csv:\n  Expected: {expected}")

    log("Successfully verified native regex pattern matching, capture groups, and threat classification!")
    print("\n  [PASS] NATIVE BASH REGEX & BASH_REMATCH VERIFIED SUCCESSFULLY.")


if __name__ == "__main__":
    main()
