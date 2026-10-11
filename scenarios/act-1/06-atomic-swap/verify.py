#!/usr/bin/env python3
"""Fast state-driven verification for Mission 1.06: The Atomic Swap."""
import os
import re
import subprocess
import sys
import threading
import time
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "swap.sh"
    current_link = workspace / "current"
    version_file = current_link / "version.txt"

    if not script.exists():
        fail("Missing required script: swap.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing atomic rename semantics in swap.sh...")
    for line in active_code.splitlines():
        clean_line = line.split("#")[0].strip()
        if re.search(r"\brm\s+.*(\bcurrent(?!\.tmp|\.bak)|\$SYMLINK_PATH|\${SYMLINK_PATH})", clean_line):
            fail("Dangerous non-atomic 'rm current' detected! Deleting symlinks creates a missing-path race condition.")

    if "mv -T" not in active_code and "rename" not in active_code:
        fail("Missing atomic symlink rename: use 'mv -T <temp_link> current' to invoke kernel rename(2).")

    # Reset initial symlink
    if current_link.is_symlink() or current_link.exists():
        current_link.unlink()
    current_link.symlink_to("releases/v1")

    # 2. Concurrency stress test
    log("Spinning up active concurrent reader traffic (querying current/version.txt)...")
    stop_event = threading.Event()
    read_errors = []
    reads_performed = 0

    def reader_loop():
        nonlocal reads_performed
        while not stop_event.is_set():
            reads_performed += 1
            try:
                text = version_file.read_text(encoding="utf-8")
                if "VERSION" not in text:
                    read_errors.append(f"Corrupted read: {text}")
            except Exception as e:
                read_errors.append(f"Missing path error during swap: {e}")

    thread = threading.Thread(target=reader_loop, daemon=True)
    thread.start()

    # Trigger the swap while reader is hitting it
    time.sleep(0.02)
    res = subprocess.run(
        ["bash", str(script), "releases/v2"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    time.sleep(0.02)
    stop_event.set()
    thread.join(timeout=1.0)

    if res.returncode != 0:
        fail(f"swap.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    # 3. Analyze concurrency results
    log(f"Reader performed {reads_performed} concurrent queries during release rotation.")
    if read_errors:
        fail(f"DOWNTIME DETECTED! {len(read_errors)} requests hit missing/broken symlinks: {read_errors[0]}")

    # 4. Verify target state
    if not current_link.is_symlink():
        fail("'current' is not a symlink.")

    target = os.readlink(str(current_link))
    if "releases/v2" not in target:
        fail(f"'current' points to '{target}', expected 'releases/v2'.")

    log("Active traffic survived release rotation with 0 downtime and 0 broken paths.")
    print("\n  [PASS] ZERO-DOWNTIME ATOMIC SYMLINK ROTATION (mv -T) VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
