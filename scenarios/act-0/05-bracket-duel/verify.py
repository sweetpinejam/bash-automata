#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.05: The Bracket Duel."""
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
    script = workspace / "validator.sh"

    if not script.exists():
        fail("Missing required script: validator.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"validator.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit for [[ ]] and absence of [
    log("Auditing bracket modernizations in validator.sh...")
    content = script.read_text(encoding="utf-8")
    active_lines = [l.strip() for l in content.splitlines() if l.strip() and not l.strip().startswith("#")]
    active_code = "\n".join(active_lines)

    # Check for legacy single bracket usage
    if re.search(r'(^|\s)\[\s+[^\[]', active_code):
        fail("Detected legacy single bracket '['. Replace all test brackets with modern '[[ ]]' compound keywords.")

    if re.search(r'\s+-[ao]\s+', active_code):
        fail("Detected legacy '-a' or '-o' logical flag. Use native '&&' and '||' inside '[[ ]]'.")

    if "[[" not in active_code:
        fail("Missing required compound '[[ ]]' test constructs.")

    # Test cases: (args, expected_code, expected_phrase, description)
    test_cases = [
        (["", "standard", "3", "main"], 2, "REJECTED: MISSING_TARGET_ENV", "Empty TARGET_ENV"),
        (["   ", "standard", "3", "main"], 2, "REJECTED: MISSING_TARGET_ENV", "Whitespace TARGET_ENV"),
        (["dev", "standard", "not_a_number", "main"], 2, "REJECTED: INVALID_REPLICA_COUNT", "Non-numeric replicas"),
        (["dev", "standard", "0", "main"], 2, "REJECTED: INVALID_REPLICA_COUNT", "Zero replicas"),
        (["dev", "standard", "99", "main"], 2, "REJECTED: INVALID_REPLICA_COUNT", "Excessive replicas (>50)"),
        (["production", "critical", "2", "main"], 2, "REJECTED: INSUFFICIENT_CRITICAL_REPLICAS", "Prod critical < 3 replicas"),
        (["production", "critical", "4", "feat/auth"], 2, "REJECTED: UNAPPROVED_BRANCH_FOR_PROD", "Prod critical unapproved branch"),
        (["production", "critical", "4", "release/v1.0"], 0, "MANUAL_APPROVAL_REQUIRED", "Prod critical valid release"),
        (["production", "critical", "5", "main"], 0, "MANUAL_APPROVAL_REQUIRED", "Prod critical valid main"),
        (["production", "standard", "2", "hotfix/cve-123"], 0, "AUTO_APPROVED", "Prod standard valid hotfix"),
        (["canary", "standard", "8", "main"], 2, "REJECTED: CANARY_REPLICA_EXCEEDED", "Canary > 5 replicas"),
        (["canary", "standard", "3", "main"], 0, "AUTO_APPROVED", "Canary valid replicas"),
        (["staging", "standard", "2", "feat/any"], 0, "AUTO_APPROVED", "Staging auto approved"),
        (["dev", "standard", "1", "feat/any"], 0, "AUTO_APPROVED", "Dev auto approved"),
        (["sandbox_qa", "standard", "2", "main"], 2, "REJECTED: UNKNOWN_ENVIRONMENT", "Unknown environment"),
    ]

    for args, exp_code, exp_phrase, desc in test_cases:
        res = subprocess.run(
            ["bash", str(script)] + args,
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=3,
        )
        if res.returncode != exp_code:
            fail(f"Test '{desc}' failed: Expected exit code {exp_code}, got {res.returncode}. Output: {res.stdout.strip()} Stderr: {res.stderr.strip()}")
        if exp_phrase not in res.stdout:
            fail(f"Test '{desc}' failed: Expected '{exp_phrase}' in output. Got: {res.stdout.strip()}")

    log(f"Successfully validated all {len(test_cases)} policy cases with modern [[ ]] compound checks!")
    print("\n  [PASS] BRACKET DUEL POLICY ENGINE VERIFIED SUCCESSFULLY.")


if __name__ == "__main__":
    main()
