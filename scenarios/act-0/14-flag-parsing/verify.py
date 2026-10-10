#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.14: Flag & Argument Parsing."""
import os
import subprocess
import sys
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def parse_cfg(path: Path) -> dict:
    if not path.exists():
        return {}
    res = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            res[k.strip()] = v.strip()
    return res


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "migrator.sh"
    cfg_file = workspace / "migration.cfg"

    if not script.exists():
        fail("Missing required script: migrator.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing flag parsing loop with shift in migrator.sh...")
    if "shift" not in active_code:
        fail("Missing 'shift' keyword for argument consumption.")

    if "$#" not in active_code:
        fail("Missing '$#' argument counter check.")

    # 2. Execution test with reordered flags
    log("Test 1: Testing arbitrary argument ordering (--dry-run -v --env production)...")
    res1 = subprocess.run(
        ["bash", str(script), "--dry-run", "-v", "--env", "production"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res1.returncode != 0:
        fail(f"migrator.sh failed with exit code {res1.returncode}. Stderr: {res1.stderr.strip()}")

    cfg1 = parse_cfg(cfg_file)
    if cfg1.get("ENV") != "production":
        fail(f"Expected ENV=production, got '{cfg1.get('ENV')}'")
    if cfg1.get("DRY_RUN") != "true":
        fail(f"Expected DRY_RUN=true, got '{cfg1.get('DRY_RUN')}'")
    if cfg1.get("VERBOSE") != "true":
        fail(f"Expected VERBOSE=true, got '{cfg1.get('VERBOSE')}'")

    # 3. Execution test with minimal flag
    log("Test 2: Testing single flag (-e staging)...")
    res2 = subprocess.run(
        ["bash", str(script), "-e", "staging"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res2.returncode != 0:
        fail(f"migrator.sh failed with exit code {res2.returncode}")

    cfg2 = parse_cfg(cfg_file)
    if cfg2.get("ENV") != "staging":
        fail(f"Expected ENV=staging, got '{cfg2.get('ENV')}'")
    if cfg2.get("DRY_RUN") != "false":
        fail(f"Expected DRY_RUN=false, got '{cfg2.get('DRY_RUN')}'")
    if cfg2.get("VERBOSE") != "false":
        fail(f"Expected VERBOSE=false, got '{cfg2.get('VERBOSE')}'")

    log("Parsed reordered flags and values with 100% accuracy.")
    print("\n  [PASS] POSITIONAL FLAG PARSING AND CONSUMPTION VIA SHIFT VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
