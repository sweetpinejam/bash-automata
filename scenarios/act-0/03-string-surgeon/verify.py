#!/usr/bin/env python3
"""Fast state-driven verification for Drill 0.03: The String Surgeon."""
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
    out_dir = workspace / "catalog_out"

    if not script.exists():
        fail("Missing required script: sorter.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"sorter.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit: strictly no external tools for string manipulation
    log("Auditing pure shell in-memory string surgery in sorter.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    import re
    for banned in ["basename", "dirname", "cut", "sed", "awk", "tr", "python", "perl"]:
        if re.search(r"\b" + re.escape(banned) + r"\b", active_code):
            fail(f"Prohibited external command '{banned}' detected. Use pure parameter expansion (${{VAR##...}}, ${{VAR%...}}).")

    if "##*/" not in active_code and "#*/" not in active_code:
        fail("Missing in-memory path stripping parameter expansion (${filepath##*/}).")

    # Run sorter.sh
    log("Executing pure in-memory artifact sorter...")
    res = subprocess.run(
        ["bash", str(script), str(incoming), str(out_dir)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"sorter.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "CATALOG_COMPLETE:" not in res.stdout:
        fail("sorter.sh did not emit expected 'CATALOG_COMPLETE:' summary.")

    if not out_dir.exists():
        fail("Output directory 'catalog_out' was not created.")

    # Validate categorized files
    log("Validating sorted directory hierarchy...")
    expected_files = {
        "archives": ["backend-api.prod.tar.gz", "worker.service.tar.xz"],
        "configs": ["config.cluster.yaml"],
        "databases": ["database-dump.backup.sql", "schema.sql"],
        "binaries": ["daemon-runner", "deploy.sh"],
    }

    for cat, files in expected_files.items():
        cat_dir = out_dir / cat
        if not cat_dir.exists():
            fail(f"Expected category directory '{cat}' was not created.")
        for f in files:
            target_f = cat_dir / f
            if not target_f.exists():
                fail(f"File '{f}' was not moved into '{cat}/'.")

    # Ensure incoming is completely cleared
    remaining = list(incoming.iterdir())
    if remaining:
        fail(f"Incoming directory still contains {len(remaining)} un-sorted files.")

    # Validate catalog.tsv contents
    log("Validating catalog.tsv metadata index...")
    catalog_tsv = out_dir / "catalog.tsv"
    if not catalog_tsv.exists():
        fail("Missing 'catalog.tsv' in output directory.")

    tsv_lines = [l.strip() for l in catalog_tsv.read_text(encoding="utf-8").splitlines() if l.strip()]
    if len(tsv_lines) != 7:
        fail(f"Expected 7 lines in catalog.tsv, found {len(tsv_lines)}.")

    tsv_dict = {}
    for line in tsv_lines:
        parts = line.split("\t")
        if len(parts) < 4:
            fail(f"Malformed line in catalog.tsv (expected 4 tab-separated fields): '{line}'")
        tsv_dict[parts[0]] = (parts[1], parts[2], parts[3])

    # Check compound archive
    if "backend-api.prod.tar.gz" not in tsv_dict:
        fail("Missing 'backend-api.prod.tar.gz' in catalog.tsv.")
    cat, stem, ext = tsv_dict["backend-api.prod.tar.gz"]
    if cat != "archives" or ext != "tar.gz" or stem != "backend-api.prod":
        fail(f"Incorrect compound metadata for backend-api.prod.tar.gz: cat={cat}, stem={stem}, ext={ext}")

    # Check binary without extension
    if "daemon-runner" not in tsv_dict:
        fail("Missing 'daemon-runner' in catalog.tsv.")
    cat, stem, ext = tsv_dict["daemon-runner"]
    if cat != "binaries" or ext != "none" or stem != "daemon-runner":
        fail(f"Incorrect no-extension metadata for daemon-runner: cat={cat}, stem={stem}, ext={ext}")

    log("Successfully verified pure in-memory string surgery, compound extensions, and TSV cataloging!")
    print("\n  [PASS] PURE IN-MEMORY STRING SURGERY FULLY VERIFIED.")


if __name__ == "__main__":
    main()
