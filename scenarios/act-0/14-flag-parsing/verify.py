#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.14: Flag & Argument Parsing."""
import json
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
    script = workspace / "migrator.sh"
    plan_file = workspace / "migration_plan.json"

    if not script.exists():
        fail("Missing required script: migrator.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"migrator.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit for while-case-shift
    log("Auditing while-case-shift parser construction in migrator.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    if "shift" not in active_code:
        fail("Missing required 'shift' operator.")
    if not re.search(r'\bcase\s+.*\s+in\b', active_code) or "esac" not in active_code:
        fail("Missing required 'case ... in ... esac' argument matching construct.")

    # Test 1: Attached syntax and reordered flags
    log("Testing attached options (--env=staging --timeout=45)...")
    res1 = subprocess.run(
        ["bash", str(script), "--dry-run", "--env=staging", "--timeout=45", "--batch-size=500", "20261011_add_table"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res1.returncode != 0:
        fail(f"migrator.sh failed on attached options: {res1.stderr.strip()}")

    if "MIGRATOR_READY:" not in res1.stdout:
        fail("migrator.sh did not emit expected 'MIGRATOR_READY:' summary.")

    if not plan_file.exists():
        fail("Missing output file: migration_plan.json")

    plan1 = json.loads(plan_file.read_text(encoding="utf-8"))
    if plan1.get("env") != "staging":
        fail(f"Expected env='staging', got '{plan1.get('env')}'")
    if plan1.get("dry_run") is not True:
        fail("Expected dry_run=true")
    if plan1.get("timeout") != 45:
        fail(f"Expected timeout=45, got {plan1.get('timeout')}")
    if plan1.get("batch_size") != 500:
        fail(f"Expected batch_size=500, got {plan1.get('batch_size')}")
    if plan1.get("target") != "20261011_add_table":
        fail(f"Expected target='20261011_add_table', got '{plan1.get('target')}'")

    # Test 2: Short space-separated options in arbitrary order
    log("Testing short options (-e production -d -v -t 120)...")
    res2 = subprocess.run(
        ["bash", str(script), "-v", "-d", "-e", "production", "-t", "120"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res2.returncode != 0:
        fail(f"migrator.sh failed on short options: {res2.stderr.strip()}")

    plan2 = json.loads(plan_file.read_text(encoding="utf-8"))
    if plan2.get("env") != "production" or plan2.get("verbose") is not True or plan2.get("dry_run") is not True:
        fail(f"Incorrect short option parsing: {plan2}")
    if plan2.get("timeout") != 120:
        fail(f"Expected timeout=120, got {plan2.get('timeout')}")
    if plan2.get("target") != "all":
        fail(f"Expected default target='all', got '{plan2.get('target')}'")

    # Test 3: End-of-options marker (--)
    log("Testing end-of-options delimiter (--)...")
    res3 = subprocess.run(
        ["bash", str(script), "--force", "--", "-dash-prefixed-target"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res3.returncode != 0:
        fail(f"migrator.sh failed with '--' delimiter: {res3.stderr.strip()}")

    plan3 = json.loads(plan_file.read_text(encoding="utf-8"))
    if plan3.get("target") != "-dash-prefixed-target":
        fail(f"Expected target='-dash-prefixed-target', got '{plan3.get('target')}'")

    # Test 4: Invalid environment validation
    log("Testing validation for invalid environment...")
    res4 = subprocess.run(["bash", str(script), "--env=invalid_env"], cwd=str(workspace), capture_output=True, text=True)
    if res4.returncode == 0:
        fail("migrator.sh must exit 1 when an invalid environment is supplied.")

    # Test 5: Invalid timeout validation
    log("Testing validation for invalid timeout...")
    res5 = subprocess.run(["bash", str(script), "--timeout=0"], cwd=str(workspace), capture_output=True, text=True)
    if res5.returncode == 0:
        fail("migrator.sh must exit 1 when timeout is out of range.")

    # Test 6: Unknown option rejection
    log("Testing unknown option rejection...")
    res6 = subprocess.run(["bash", str(script), "--unknown-flag"], cwd=str(workspace), capture_output=True, text=True)
    if res6.returncode == 0:
        fail("migrator.sh must exit 1 when an unknown option is supplied.")

    log("Successfully verified short/long flags, attached syntax, validation, and JSON plan generation!")
    print("\n  [PASS] POSITIONAL FLAG PARSING AND CONSUMPTION VIA SHIFT VERIFIED.")


if __name__ == "__main__":
    main()
