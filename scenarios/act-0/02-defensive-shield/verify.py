#!/usr/bin/env python3
"""State-driven verification for Drill 0.2: The Defensive Shield."""
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
    deploy_sh = workspace / "deploy.sh"

    if not deploy_sh.exists():
        fail("Missing required script: deploy.sh")

    content = deploy_sh.read_text(encoding="utf-8")

    log("Auditing defensive shell flags in deploy.sh...")
    # Check for active set -euo pipefail
    code_lines = [l for l in content.splitlines() if not l.strip().startswith("#")]
    active_code = "\n".join(code_lines)

    if "set -euo pipefail" not in active_code and not ("set -e" in active_code and "pipefail" in active_code):
        fail("deploy.sh must declare 'set -euo pipefail' to enforce strict error handling.")

    log("Executing deploy.sh under normal conditions...")
    res = subprocess.run(
        ["bash", str(deploy_sh)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res.returncode != 0:
        fail(f"deploy.sh exited with code {res.returncode}. Stderr: {res.stderr}")

    if "DEPLOYMENT_SUCCESSFUL" not in res.stdout:
        fail("deploy.sh did not complete execution cleanly.")

    log("Defensive shell options successfully verified.")
    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
