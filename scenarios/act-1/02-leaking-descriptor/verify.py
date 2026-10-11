#!/usr/bin/env python3
"""Fast state-driven verification for Mission 1.02: The Leaking Descriptor."""
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
    script = workspace / "monitor.sh"
    summary_file = workspace / "monitor.summary"

    if not script.exists():
        fail("Missing required script: monitor.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing descriptor cleanup syntax in monitor.sh...")
    if "<&-" not in active_code and ">&-" not in active_code:
        fail("Missing file descriptor closure syntax (e.g., 'exec {fd}<&-' or 'exec 3<&-')")

    # 2. Execution under restrictive file descriptor ceiling (ulimit -n 25)
    log("Executing monitor daemon under strict OS descriptor ceiling (ulimit -n 25)...")
    res = subprocess.run(
        ["bash", "-c", f"ulimit -n 25; bash {script} 50"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )

    if res.returncode != 0:
        if "Too many open files" in res.stderr:
            fail("KERNEL EXHAUSTION: 'Too many open files' triggered! Descriptor table leaked across polling cycles.")
        fail(f"monitor.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "MONITOR_RUN_COMPLETE" not in res.stdout:
        fail("monitor.sh did not complete 50 cycles cleanly.")

    # 3. File validation
    if not summary_file.exists():
        fail("Summary file 'monitor.summary' missing.")

    lines = [l for l in summary_file.read_text(encoding="utf-8").splitlines() if l.strip()]
    if len(lines) != 50:
        fail(f"Expected 50 status cycles in summary, found {len(lines)}")

    log("Completed 50 polling cycles with 0 descriptor leaks under 25-FD ceiling.")
    print("\n  [PASS] FILE DESCRIPTOR TABLE LIFECYCLE DEFENSE VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
