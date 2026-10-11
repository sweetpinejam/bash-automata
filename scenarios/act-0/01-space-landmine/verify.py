#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.01: The Space Landmine."""
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

    # Static Syntax Check
    syntax_check = subprocess.run(["bash", "-n", str(cleaner_sh)], capture_output=True, text=True)
    if syntax_check.returncode != 0:
        fail(f"cleaner.sh has syntax errors: {syntax_check.stderr.strip()}")

    # Test 1: Missing Arguments Validation
    log("Testing CLI argument validation (missing arguments)...")
    res_no_args = subprocess.run(
        ["bash", str(cleaner_sh)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
    )
    if res_no_args.returncode == 0:
        fail("cleaner.sh must exit 1 when invoked with missing arguments.")

    # Test 2: Non-existent Source Directory
    log("Testing non-existent source directory check...")
    res_bad_src = subprocess.run(
        ["bash", str(cleaner_sh), "non_existent_directory_xyz", "dest_dir"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
    )
    if res_bad_src.returncode == 0:
        fail("cleaner.sh must exit 1 when source directory does not exist.")

    # Test 3: Dry-Run Mode
    log("Testing --dry-run mode execution...")
    res_dry = subprocess.run(
        ["bash", str(cleaner_sh), "--dry-run", str(src_dir), str(dest_dir)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res_dry.returncode != 0:
        fail(f"cleaner.sh --dry-run failed with code {res_dry.returncode}: {res_dry.stderr.strip()}")

    if "[DRY_RUN]" not in res_dry.stdout:
        fail("cleaner.sh --dry-run did not emit '[DRY_RUN]' notices.")

    if "dry_run=1" not in res_dry.stdout:
        fail("cleaner.sh --dry-run did not report 'dry_run=1' in summary output.")

    if dest_dir.exists():
        fail("cleaner.sh --dry-run must NOT create the destination directory.")

    # Ensure source files are untouched during dry run
    source_files_dry = list(src_dir.rglob("*"))
    source_regular_files = [f for f in source_files_dry if f.is_file()]
    if len(source_regular_files) < 3:
        fail("cleaner.sh --dry-run modified or deleted files in the source directory.")

    # Test 4: Live Archival Sweep
    log("Testing live archival sweep...")
    res_live = subprocess.run(
        ["bash", str(cleaner_sh), str(src_dir), str(dest_dir)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res_live.returncode != 0:
        fail(f"cleaner.sh live run failed with code {res_live.returncode}: {res_live.stderr.strip()}")

    if "SWEEP_COMPLETE:" not in res_live.stdout or "dry_run=0" not in res_live.stdout:
        fail("cleaner.sh live run did not report valid SWEEP_COMPLETE summary.")

    if not dest_dir.exists():
        fail("Destination directory 'archived runs' was not created.")

    manifest_file = dest_dir / "manifest.tsv"
    if not manifest_file.exists():
        fail("Missing required 'manifest.tsv' inside destination directory.")

    manifest_content = manifest_file.read_text(encoding="utf-8")

    expected_files = ["run telemetry.log", "crash dump.txt", "build report.log"]
    for fname in expected_files:
        archived_file = dest_dir / fname
        if not archived_file.exists():
            fail(f"File '{fname}' was not moved into '{dest_dir.name}'.")
        if fname not in manifest_content:
            fail(f"File '{fname}' is missing from manifest.tsv.")

    # Verify source directory contains no leftover regular files
    remaining_regular = [f for f in src_dir.rglob("*") if f.is_file()]
    if remaining_regular:
        fail(f"Source directory still contains {len(remaining_regular)} un-swept regular files.")

    log("Successfully verified argument safety, dry-run protection, and whitespace resilience!")
    print("\n  [PASS] ALL WHITESPACE & WORD-SPLITTING CHECKS VERIFIED SUCCESSFULLY.")


if __name__ == "__main__":
    main()
