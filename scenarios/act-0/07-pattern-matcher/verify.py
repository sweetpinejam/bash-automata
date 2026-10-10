#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.07: Pattern & Regex Matching."""
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
    script = workspace / "classifier.sh"
    csv_file = workspace / "threats.csv"

    if not script.exists():
        fail("Missing required script: classifier.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing native regex pattern matching in classifier.sh...")
    for banned in ["grep", "sed", "awk", "cut", "python", "perl"]:
        if banned in active_code:
            fail(f"Prohibited external command '{banned}' detected. Use native '[[ $line =~ pattern ]]' and 'BASH_REMATCH'.")

    if "=~" not in active_code:
        fail("Missing native Bash regex matching operator '=~'")

    if "BASH_REMATCH" not in active_code:
        fail("Missing reference to '${BASH_REMATCH[...]}' capture group array")

    # 2. Execution
    log("Executing security log classifier...")
    res = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"classifier.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "CLASSIFICATION_COMPLETE" not in res.stdout:
        fail("classifier.sh did not complete cleanly.")

    # 3. Validation
    log("Validating generated threats.csv...")
    if not csv_file.exists():
        fail("Output file 'threats.csv' was not generated.")

    lines = [l.strip() for l in csv_file.read_text(encoding="utf-8").splitlines() if l.strip()]
    expected_lines = [
        "IP,PORT,REASON",
        "192.168.1.50,443,SYN_FLOOD",
        "172.16.0.99,22,SSH_BRUTEFORCE",
        "203.0.113.5,8080,SQL_INJECTION",
    ]

    if lines != expected_lines:
        fail(f"Output mismatch.\nExpected:\n{expected_lines}\nGot:\n{lines}")

    log("Extracted 3 alert threats with accurate IP, Port, and Reason fields.")
    print("\n  [PASS] ALL REGEX PATTERNS MATCHED AND CAPTURED USING BASH_REMATCH.")
    sys.exit(0)


if __name__ == "__main__":
    main()
