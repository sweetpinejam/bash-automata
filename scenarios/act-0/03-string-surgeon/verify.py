#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.03: The String Surgeon."""
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
    script = workspace / "sorter.sh"
    incoming = workspace / "incoming"
    categorized = workspace / "categorized"

    if not script.exists():
        fail("Missing required script: sorter.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit for in-memory string surgery & prohibited external binaries
    log("Auditing pure shell string manipulation in sorter.sh...")
    for banned in ["basename", "dirname", "cut", "sed", "awk"]:
        if banned in active_code:
            fail(f"Prohibited external command '{banned}' detected. Use native '${{VAR##...}}' expansions.")

    if "##*/" not in active_code and "#*/" not in active_code:
        fail("Missing path-stripping pattern expansion (e.g., '${filepath##*/}')")

    if "##*." not in active_code and "#*." not in active_code:
        fail("Missing extension-stripping pattern expansion (e.g., '${filename##*.}')")

    # 2. Execution
    log("Running automated artifact sorter...")
    res = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"sorter.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "SORT_COMPLETE" not in res.stdout:
        fail("sorter.sh did not complete cleanly.")

    # 3. Filesystem validation
    log("Validating sorted destination structure...")
    expected_mappings = [
        ("gz", "backend-api.prod.tar.gz"),
        ("js", "frontend-app.min.js"),
        ("sql", "database-schema.backup.sql"),
    ]

    for ext_folder, fname in expected_mappings:
        target_path = categorized / ext_folder / fname
        if not target_path.exists():
            fail(f"Artifact was not sorted into expected directory: 'categorized/{ext_folder}/{fname}'")
        log(f"Verified: categorized/{ext_folder}/{fname}")

    remaining = [f.name for f in incoming.iterdir() if f.is_file()]
    if remaining:
        fail(f"Incoming directory still contains un-sorted files: {remaining}")

    print("\n  [PASS] ALL ARTIFACTS SORTED USING PURE IN-MEMORY STRING SURGERY.")
    sys.exit(0)


if __name__ == "__main__":
    main()
