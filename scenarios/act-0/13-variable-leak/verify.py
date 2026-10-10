#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.13: The Variable Leak."""
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
    script = workspace / "backup_bot.sh"
    report_file = workspace / "backup_report.txt"

    if not script.exists():
        fail("Missing required script: backup_bot.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing local variable scoping in backup_bot.sh...")
    if "local " not in active_code:
        fail("Missing 'local' variable scoping inside function.")

    # 2. Execution
    log("Running automated backup bot...")
    res = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"backup_bot.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "ALL_BACKUPS_COMPLETE" not in res.stdout:
        fail("backup_bot.sh did not complete cleanly.")

    # 3. Validation
    if not report_file.exists():
        fail("Report file 'backup_report.txt' was not generated.")

    lines = [l.strip() for l in report_file.read_text(encoding="utf-8").splitlines() if l.strip()]
    expected_lines = [
        "DAY_1: SUCCESS",
        "DAY_2: SUCCESS",
        "DAY_3: SUCCESS",
        "DAY_4: SUCCESS",
        "DAY_5: SUCCESS",
    ]

    if len(lines) == 1:
        fail("Only Day 1 was processed! Global variable leakage corrupted the outer loop counter.")

    if lines != expected_lines:
        fail(f"Backup report mismatch.\nExpected:\n{expected_lines}\nGot:\n{lines}")

    log("Verified all 5 days processed without variable scope collision.")
    print("\n  [PASS] FUNCTION VARIABLE SCOPING DEFENSE ('local') VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
