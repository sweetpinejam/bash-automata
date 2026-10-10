#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.05: The Bracket Duel."""
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

    content = script.read_text(encoding="utf-8")
    lines = [l.strip() for l in content.splitlines() if not l.strip().startswith("#")]
    active_code = "\n".join(lines)

    # 1. Static audit
    log("Auditing compound bracket syntax in validator.sh...")
    if "[[" not in active_code or "]]" not in active_code:
        fail("Missing modern compound test brackets '[[ ... ]]'")

    # Check for legacy single brackets in if/elif statements
    for line in lines:
        if line.startswith("if [ ") or line.startswith("elif [ ") or " [ " in line:
            fail(f"Found legacy single bracket test: '{line}'. Replace with '[[ ... ]]'.")
        if " -a " in line or " -o " in line:
            fail(f"Found archaic '-a' or '-o' operator: '{line}'. Use '&&' or '||' inside '[[ ... ]]'.")

    # 2. Execution tests
    test_cases = [
        # (args, expected_output, description)
        ([], "DEPLOY_VERDICT: TARGET_ENV_MISSING", "Empty / unset arguments"),
        ([""], "DEPLOY_VERDICT: TARGET_ENV_MISSING", "Explicit empty string argument"),
        (["prod cluster", "critical"], "DEPLOY_VERDICT: UNKNOWN_TARGET", "Argument with spaces (Word-splitting test)"),
        (["production", "critical"], "DEPLOY_VERDICT: MANUAL_APPROVAL_REQUIRED", "Production critical approval check"),
        (["staging"], "DEPLOY_VERDICT: AUTO_APPROVED", "Staging auto-approval check"),
        (["dev"], "DEPLOY_VERDICT: AUTO_APPROVED", "Dev auto-approval check"),
    ]

    for args, expected, desc in test_cases:
        log(f"Testing condition: {desc}...")
        res = subprocess.run(
            ["bash", str(script)] + args,
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )
        if res.returncode != 0:
            fail(f"Script crashed (exit code {res.returncode}) for args {args}. Stderr: {res.stderr.strip()}")
        if expected not in res.stdout:
            fail(f"Expected output '{expected}' not found in stdout for args {args}. Got: {res.stdout.strip()}")

    print("\n  [PASS] ALL CONDITIONAL TESTS PASSED WITHOUT WORD-SPLITTING OR SYNTAX CRASHES.")
    sys.exit(0)


if __name__ == "__main__":
    main()
