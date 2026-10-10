#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.01: The Space Landmine."""
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
    cleaner_sh = workspace / "cleaner.sh"
    src_dir = workspace / "deploy artifacts"
    dest_dir = workspace / "archived runs"

    if not cleaner_sh.exists():
        fail("Missing required script: cleaner.sh")

    content = cleaner_sh.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # Static audit
    log("Auditing quoting in cleaner.sh...")
    if '"$DEST_DIR"' not in active_code:
        fail("DEST_DIR must be enclosed in double quotes: \"$DEST_DIR\"")
    if '"$SRC_DIR"' not in active_code:
        fail("SRC_DIR must be enclosed in double quotes: \"$SRC_DIR\"/*")

    log("Executing automated cleanup sweep...")
    try:
        res = subprocess.run(
            ["bash", str(cleaner_sh)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )
    except Exception as e:
        fail(f"Execution exception: {e}")

    if res.returncode != 0:
        fail(f"cleaner.sh failed (exit code {res.returncode}). Stderr: {res.stderr.strip()}")

    if "SWEEP_COMPLETE" not in res.stdout:
        fail("cleaner.sh did not complete cleanly.")

    log("Verifying filesystem state...")
    if not dest_dir.exists():
        fail("Destination directory 'archived runs' was not created.")

    expected_files = ["run telemetry.log", "crash dump.txt"]
    for fname in expected_files:
        archived_file = dest_dir / fname
        if not archived_file.exists():
            fail(f"File '{fname}' was not moved into 'archived runs'.")

    # Ensure source directory is clean
    remaining = list(src_dir.iterdir())
    if remaining:
        fail(f"Source directory still contains {len(remaining)} un-swept files.")

    log(f"Successfully archived {len(expected_files)} files containing space characters.")
    log("Zero Word Splitting errors detected.")
    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
