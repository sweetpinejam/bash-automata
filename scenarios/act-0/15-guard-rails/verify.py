#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.15: Short-Circuit Guard Rails."""
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
    script = workspace / "publisher.sh"
    test_sh = workspace / "mock_test.sh"
    bundle_bin = workspace / "dist" / "bundle.bin"
    bundle_sig = workspace / "dist" / "bundle.sig"

    if not script.exists():
        fail("Missing required script: publisher.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing short-circuit guard rail constructs in publisher.sh...")
    if "||" not in active_code or "{" not in active_code:
        fail("Missing short-circuit guard rail pattern 'command || { ...; }'")

    if "if [ $? -eq 0 ]" in active_code or "if [ $? = 0 ]" in active_code:
        fail("Found anti-pattern 'if [ $? -eq 0 ]'. Replace with clean 'command || { exit 1; }' guard rails.")

    def run_publisher():
        return subprocess.run(
            ["bash", str(script)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )

    # 2. Test successful pass
    log("Test 1: Testing valid publication flow...")
    res1 = run_publisher()
    if res1.returncode != 0:
        fail(f"publisher.sh failed with exit code {res1.returncode}. Stderr: {res1.stderr.strip()}")

    if "PUBLISH_SUCCESS" not in res1.stdout:
        fail("Expected 'PUBLISH_SUCCESS' in output.")

    if not bundle_bin.exists() or not bundle_sig.exists():
        fail("Publication artifacts were not created in dist/")

    # 3. Test failure short-circuit
    log("Test 2: Injecting test failure into mock_test.sh...")
    test_sh.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
    # Clean up previous artifacts
    if bundle_bin.exists():
        bundle_bin.unlink()
    if bundle_sig.exists():
        bundle_sig.unlink()

    res2 = run_publisher()
    if res2.returncode == 0:
        fail("publisher.sh succeeded when test suite failed! It must halt immediately with non-zero exit code.")

    if bundle_bin.exists():
        fail("build_bundle was executed after test failure! Short-circuit guard rail failed to abort.")

    # Restore test_sh
    test_sh.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")

    log("Verified pipeline executes cleanly and short-circuits on failure.")
    print("\n  [PASS] SHORT-CIRCUIT GUARD RAILS ('|| { ...; }') VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
