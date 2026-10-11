#!/usr/bin/env python3
"""Fast state-driven verification for Mission 1.08: The Subreaper Tree."""
import os
import signal
import subprocess
import sys
import time
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def is_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "orchestrator.sh"
    gc_pids_file = workspace / "grandchildren.pids"
    pipe_pid_file = workspace / "pipeline.pid"

    if not script.exists():
        fail("Missing required script: orchestrator.sh")

    # Clean old PID files
    for f in [gc_pids_file, pipe_pid_file]:
        if f.exists():
            f.unlink()

    log("Executing orchestrator workload lifecycle...")
    try:
        res = subprocess.run(
            ["bash", str(script)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )
    except subprocess.TimeoutExpired:
        fail("orchestrator.sh timed out or lingering processes blocked output streams.")

    if res.returncode != 0:
        fail(f"orchestrator.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "TEARDOWN_FINISHED" not in res.stdout:
        fail("orchestrator.sh did not complete teardown sequence.")

    # Check for lingering grandchild processes
    if not gc_pids_file.exists():
        fail("grandchildren.pids was not recorded.")

    gc_pids = [int(p.strip()) for p in gc_pids_file.read_text().splitlines() if p.strip()]
    if not gc_pids:
        fail("No grandchild PIDs were recorded.")

    log(f"Auditing status of {len(gc_pids)} grandchild worker processes...")
    survivors = []
    for gpid in gc_pids:
        if is_running(gpid):
            survivors.append(gpid)
            # Cleanup rogue process so it doesn't leak into host
            try:
                os.kill(gpid, signal.SIGKILL)
            except OSError:
                pass

    if survivors:
        fail(f"ORPHAN LEAK DETECTED: Grandchild PIDs {survivors} survived teardown as orphaned background jobs!")

    log("Zero surviving grandchild processes detected. Complete process tree terminated.")
    print("\n  [PASS] PROCESS GROUP / TREE TERMINATION DEFENSE VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
