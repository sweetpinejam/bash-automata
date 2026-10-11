#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.13: The Variable Leak."""
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
    script = workspace / "backup_bot.sh"
    manifest_file = workspace / "backup_manifest.tsv"

    if not script.exists():
        fail("Missing required script: backup_bot.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"backup_bot.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit for local keyword
    log("Auditing function variable scoping in backup_bot.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    if not re.search(r'\blocal\s+\w+', active_code):
        fail("Missing required 'local' variable scoping inside helper functions.")

    # Test 1: Standard 5-day run
    log("Executing backup bot for default 5 days...")
    res1 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res1.returncode != 0:
        fail(f"backup_bot.sh failed with exit code {res1.returncode}. Stderr: {res1.stderr.strip()}")

    if "BACKUP_BOT_COMPLETE:" not in res1.stdout:
        fail("backup_bot.sh did not emit expected 'BACKUP_BOT_COMPLETE:' summary.")

    if not manifest_file.exists():
        fail("Manifest file 'backup_manifest.tsv' was not created.")

    lines = [l.strip() for l in manifest_file.read_text(encoding="utf-8").splitlines() if l.strip()]
    if len(lines) != 6:
        fail(f"Expected 6 lines in manifest (header + 5 days), got {len(lines)}. Check for outer loop truncation caused by leaked variables.")

    for i in range(1, 6):
        expected_entry = f"DAY_{i}\t3\tSUCCESS"
        if not any(expected_entry in l for l in lines):
            fail(f"Missing day entry '{expected_entry}' in backup_manifest.tsv.")

    # Test 2: Custom days and manifest path
    log("Testing custom arguments: --days 8 --manifest custom_manifest.tsv...")
    custom_manifest = workspace / "custom_manifest.tsv"
    res2 = subprocess.run(
        ["bash", str(script), "--days", "8", "--manifest", str(custom_manifest)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res2.returncode != 0:
        fail(f"backup_bot.sh failed on custom arguments: {res2.stderr.strip()}")

    custom_lines = [l.strip() for l in custom_manifest.read_text(encoding="utf-8").splitlines() if l.strip()]
    if len(custom_lines) != 9:
        fail(f"Expected 9 lines in custom manifest (header + 8 days), got {len(custom_lines)}.")

    log("Successfully verified function scope defense, local isolation, and full iteration survival!")
    print("\n  [PASS] FUNCTION VARIABLE SCOPING DEFENSE ('local') VERIFIED.")


if __name__ == "__main__":
    main()
