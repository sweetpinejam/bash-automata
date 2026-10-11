#!/usr/bin/env python3
"""Fast state-driven verification for Mission 1.07: The Shared Memory Bus."""
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
    script = workspace / "writer.sh"
    consumer_py = workspace / "consumer.py"
    shm_target = Path("/dev/shm/telemetry_bus.dat")

    if not script.exists():
        fail("Missing required script: writer.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing kernel shared memory location in writer.sh...")
    if "/dev/shm" not in active_code:
        fail("Missing '/dev/shm' RAM disk path in writer.sh!")

    if "trap " not in active_code or "EXIT" not in active_code:
        fail("Missing 'trap ... EXIT' cleanup to prevent unlinked memory leaks in /dev/shm.")

    # Clean target
    if shm_target.exists():
        shm_target.unlink()

    # 2. Execution: Run consumer and writer concurrently
    log("Starting consumer listener and executing shared memory telemetry stream...")
    consumer_proc = subprocess.Popen(
        ["python3", str(consumer_py), str(shm_target)],
        cwd=str(workspace),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    time.sleep(0.05)
    writer_res = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )

    if writer_res.returncode != 0:
        consumer_proc.kill()
        fail(f"writer.sh failed with exit code {writer_res.returncode}. Stderr: {writer_res.stderr.strip()}")

    c_stdout, c_stderr = consumer_proc.communicate(timeout=2.0)
    if consumer_proc.returncode != 0:
        fail(f"consumer.py failed: {c_stderr.strip()}")

    # 3. Verify clean unlinking
    if shm_target.exists():
        fail(f"Shared memory node '{shm_target}' was not unlinked on writer exit! Memory leak in tmpfs.")

    log("Consumer verified 100 frames streamed through /dev/shm RAM disk with 0 leaks.")
    print("\n  [PASS] POSIX SHARED MEMORY BUS (/dev/shm) VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
