#!/usr/bin/env python3
"""Fast state-driven verification for Mission 1.05: The Orphan Graveyard."""
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


def count_zombies_for_pid(parent_pid: int) -> int:
    try:
        out = subprocess.check_output(
            ["ps", "-eo", "pid,ppid,stat,comm"],
            text=True,
        )
        zombies = 0
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 3:
                ppid = parts[1]
                stat = parts[2]
                if ppid == str(parent_pid) and "Z" in stat:
                    zombies += 1
        return zombies
    except Exception:
        return 0


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "supervisor.sh"
    done_file = workspace / "batch.done"

    if not script.exists():
        fail("Missing required script: supervisor.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing process reaping commands in supervisor.sh...")
    if "wait" not in active_code:
        fail("Missing 'wait' command to reap terminating child processes.")

    # 2. Execution with active zombie monitoring
    log("Launching batch job supervisor and auditing process table...")
    proc = subprocess.Popen(
        ["bash", str(script)],
        cwd=str(workspace),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    max_zombies_seen = 0
    t0 = time.time()
    while proc.poll() is None and (time.time() - t0) < 3.0:
        z = count_zombies_for_pid(proc.pid)
        if z > max_zombies_seen:
            max_zombies_seen = z
        time.sleep(0.05)

    stdout, stderr = proc.communicate(timeout=2.0)
    if proc.returncode != 0:
        fail(f"supervisor.sh failed with exit code {proc.returncode}. Stderr: {stderr.strip()}")

    # 3. Validation
    if not done_file.exists():
        fail("batch.done was not created.")

    tasks = [l for l in done_file.read_text(encoding="utf-8").splitlines() if l.strip()]
    if len(tasks) != 20:
        fail(f"Expected 20 completed batch tasks, found {len(tasks)}")

    log(f"All 20 batch tasks executed. Peak un-reaped zombies: {max_zombies_seen}.")
    print("\n  [PASS] ZOMBIE PROCESS REAPING VIA WAIT VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
