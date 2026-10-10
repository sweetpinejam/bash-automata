#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.10: The Subshell Ghost."""
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
    script = workspace / "auditor.sh"
    audit_file = workspace / "audit.out"

    if not script.exists():
        fail("Missing required script: auditor.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing subshell avoidance in auditor.sh...")
    if "| while" in active_code or "|while" in active_code:
        fail("Prohibited '| while' pipeline detected! Pipelines run loops in isolated subshells where variables vanish.")

    if "< <(" not in active_code and "< <(tail" not in active_code and "< ledger.csv" not in active_code:
        fail("Missing non-piped loop redirection (e.g. process substitution 'done < <(tail -n +2 ledger.csv)')")

    # 2. Execution
    log("Executing financial ledger auditor...")
    res = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"auditor.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "FINAL_AUDIT_TOTAL=0" in res.stdout:
        fail("FINAL_AUDIT_TOTAL was 0! Variable total_amount was lost inside an isolated subshell.")

    if "FINAL_AUDIT_TOTAL=3750" not in res.stdout:
        fail(f"Expected FINAL_AUDIT_TOTAL=3750 (500 + 1250 + 2000), got: {res.stdout.strip()}")

    # 3. File validation
    if not audit_file.exists():
        fail("Output file 'audit.out' was not generated.")

    saved_text = audit_file.read_text(encoding="utf-8").strip()
    if "FINAL_AUDIT_TOTAL=3750" not in saved_text:
        fail(f"audit.out contents mismatch: '{saved_text}'")

    log("Calculated exact audit total of $3,750 with parent-shell variable persistence.")
    print("\n  [PASS] SUBSHELL GHOST DEFEATED VIA PROCESS SUBSTITUTION.")
    sys.exit(0)


if __name__ == "__main__":
    main()
