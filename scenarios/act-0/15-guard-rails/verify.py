#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.15: Short-Circuit Guard Rails."""
import os
import re
import shutil
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
    script = workspace / "publisher.sh"
    dist_dir = workspace / "dist"

    if not script.exists():
        fail("Missing required script: publisher.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"publisher.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit: strictly no nested if [ $? -eq 0 ]
    log("Auditing short-circuit guard rails and absence of Arrow anti-pattern...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    if re.search(r'if\s+\[\s*\$\?\s+-eq\s+0\s*\]', active_code):
        fail("Arrow anti-pattern detected: 'if [ $? -eq 0 ]' creates fragile, deeply nested pipelines.")

    if not re.search(r'\|\|\s*\{', active_code):
        fail("Missing required short-circuit guard rail pattern: 'command || { ...; }'.")

    # Test 1: Successful publication pipeline
    log("Executing publisher pipeline with valid version...")
    res1 = subprocess.run(
        ["bash", str(script), "--version", "2.4.0"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res1.returncode != 0:
        fail(f"publisher.sh failed with exit code {res1.returncode}. Stderr: {res1.stderr.strip()}")

    if "PUBLISH_COMPLETE:" not in res1.stdout:
        fail("publisher.sh did not emit expected 'PUBLISH_COMPLETE:' summary.")

    manifest_json = dist_dir / "manifest.json"
    manifest_sha = dist_dir / "manifest.sha256"
    release_tar = dist_dir / "release.tar.gz"

    if not manifest_json.exists():
        fail("dist/manifest.json was not created.")
    if not manifest_sha.exists():
        fail("dist/manifest.sha256 was not created.")
    if not release_tar.exists():
        fail("dist/release.tar.gz package was not created.")

    # Verify tarball contents with real tar
    tar_check = subprocess.run(["tar", "-tzf", str(release_tar)], capture_output=True, text=True)
    if tar_check.returncode != 0 or "manifest.json" not in tar_check.stdout:
        fail("Created tarball is corrupt or missing required manifest.")

    # Test 2: Fail-fast guard rail on invalid version
    log("Testing fail-fast guard rail with invalid version...")
    shutil.rmtree(dist_dir, ignore_errors=True)
    res2 = subprocess.run(
        ["bash", str(script), "--version", "bad_version_str"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res2.returncode == 0:
        fail("publisher.sh must fail fast and exit 1 on invalid version format.")

    if release_tar.exists():
        fail("Fail-fast breach: Downstream tarball was created even though validation failed!")

    log("Successfully verified short-circuit guard rails, fail-fast defense, and tar packaging!")
    print("\n  [PASS] SHORT-CIRCUIT GUARD RAILS ('|| { ...; }') VERIFIED.")


if __name__ == "__main__":
    main()
