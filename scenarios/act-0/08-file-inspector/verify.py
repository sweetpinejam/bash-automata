#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.08: The File Inspector."""
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
    script = workspace / "preflight.sh"
    config_file = workspace / "config" / "app.conf"
    releases_dir = workspace / "releases"
    app_bin = workspace / "bin" / "app"

    if not script.exists():
        fail("Missing required script: preflight.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing file test operators in preflight.sh...")
    if "-s" not in active_code:
        fail("Missing non-empty file test operator '-s'")
    if "-d" not in active_code:
        fail("Missing directory test operator '-d'")
    if "-x" not in active_code:
        fail("Missing executable test operator '-x'")

    def run_check():
        return subprocess.run(
            ["bash", str(script)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )

    # 2. Test valid baseline
    log("Test 1: Running with valid prerequisites...")
    res = run_check()
    if res.returncode != 0:
        fail(f"preflight.sh failed on valid environment (exit code {res.returncode}). Stderr: {res.stderr.strip()}")
    if "ALL_CHECKS_PASSED" not in res.stdout:
        fail("Expected 'ALL_CHECKS_PASSED' in stdout.")

    # 3. Test empty config
    log("Test 2: Testing empty configuration file (zero bytes)...")
    config_file.write_text("", encoding="utf-8")
    res_empty = run_check()
    if res_empty.returncode == 0:
        fail("preflight.sh succeeded with an empty config file! Must fail when file is 0 bytes.")
    config_file.write_text("PORT=8080\n", encoding="utf-8")

    # 4. Test missing directory
    log("Test 3: Testing missing directory...")
    if releases_dir.exists():
        releases_dir.rmdir()
    res_nodir = run_check()
    if res_nodir.returncode == 0:
        fail("preflight.sh succeeded with missing releases directory! Must fail.")
    releases_dir.mkdir(exist_ok=True)

    # 5. Test non-executable binary
    log("Test 4: Testing non-executable binary permissions...")
    app_bin.chmod(0o644)
    res_noexec = run_check()
    if res_noexec.returncode == 0:
        fail("preflight.sh succeeded when bin/app had no execute permissions! Must fail.")
    app_bin.chmod(0o755)

    print("\n  [PASS] ALL FILE TESTS (-s, -d, -x) VERIFIED ACROSS POSITIVE AND NEGATIVE SCENARIOS.")
    sys.exit(0)


if __name__ == "__main__":
    main()
