#!/usr/bin/env python3
"""State assertion test for Mission 2.02: The Runaway Worker Pool."""
import os
import subprocess
import sys
import time
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    pool_sh = workspace / "pool_manager.sh"
    log_file = workspace / "processed.log"

    if not pool_sh.exists():
        fail("Missing required script: pool_manager.sh")

    content = pool_sh.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    log("Auditing dynamic slot replenishment in pool_manager.sh...")
    if "wait -n" not in active_code:
        fail("pool_manager.sh must use dynamic slot replenishment ('wait -n') to avoid lockstep idle stalls.")

    if log_file.exists():
        log_file.unlink()

    log("Benchmarking worker pool pipeline execution...")
    t0 = time.monotonic()
    try:
        proc = subprocess.run(
            ["bash", str(pool_sh)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )
    except subprocess.TimeoutExpired:
        fail("pool_manager.sh timed out (>5s)!")
    except Exception as e:
        fail(f"Execution error: {e}")
    duration = time.monotonic() - t0

    if proc.returncode != 0:
        fail(f"pool_manager.sh failed with exit code {proc.returncode}.\nStderr: {proc.stderr.strip()}")

    if "POOL_DRAINED" not in proc.stdout:
        fail("pool_manager.sh did not complete cleanly or output 'POOL_DRAINED'.")

    log(f"Worker pool completed in {duration:.3f}s")

    if not log_file.exists():
        fail("No processed tasks recorded in processed.log.")

    processed = [l.strip() for l in log_file.read_text(encoding="utf-8").splitlines() if l.strip()]
    log(f"Total processed tasks: {len(processed)}/9")

    if len(processed) != 9:
        fail(f"Expected 9 processed tasks, found {len(processed)}.")

    log("DYNAMIC POOL ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
