#!/usr/bin/env python3
"""Fast state-driven verification for Mission 1.03: The Silent Deadlock."""
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


def cleanup(workspace: Path):
    # Unlink any stale FIFOs and log files
    for fifo in ["req.fifo", "resp.fifo"]:
        p = workspace / fifo
        if p.exists():
            p.unlink(missing_ok=True)
    (workspace / "handshake.log").unlink(missing_ok=True)


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "agent.sh"
    log_file = workspace / "handshake.log"

    if not script.exists():
        fail("Missing required script: agent.sh")

    cleanup(workspace)

    # 1. Execution with strict anti-deadlock timeout
    log("Executing bidirectional FIFO handshake under 3.0s anti-hang watchdog...")
    t0 = time.time()
    try:
        res = subprocess.run(
            ["bash", str(script)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=3.0,
        )
    except subprocess.TimeoutExpired:
        # Safely terminate any stalled controller daemon
        subprocess.run(["pkill", "-9", "-f", "^python3.*controller.py"], capture_output=True)
        cleanup(workspace)
        fail("DEADLOCK DETECTED: agent.sh hung waiting on FIFO open()! Mutual blocking read/write freeze.")

    elapsed = time.time() - t0
    if res.returncode != 0:
        fail(f"agent.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "HANDSHAKE_COMPLETE" not in res.stdout:
        fail("agent.sh did not complete handshake.")

    # 2. Validate handshake.log
    log("Verifying handshake transaction integrity...")
    if not log_file.exists():
        fail("handshake.log was not generated.")

    content = log_file.read_text(encoding="utf-8").strip()
    if "HANDSHAKE_ACK_RECEIVED" not in content:
        fail(f"Expected 'HANDSHAKE_ACK_RECEIVED' in handshake.log, got: '{content}'")

    log(f"Bidirectional handshake completed smoothly in {elapsed:.2f}s with zero deadlocks.")
    print("\n  [PASS] KERNEL PIPE DEADLOCK RESOLVED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
