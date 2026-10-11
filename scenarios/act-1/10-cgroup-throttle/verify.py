#!/usr/bin/env python3
"""Fast state-driven verification for Mission 1.10: The Kernel Cgroup Throttle."""
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


def get_peak_rss_mb(pid: int) -> float:
    try:
        status_path = Path(f"/proc/{pid}/status")
        if status_path.exists():
            for line in status_path.read_text().splitlines():
                if line.startswith("VmHWM:") or line.startswith("VmRSS:"):
                    parts = line.split()
                    return int(parts[1]) / 1024.0
    except Exception:
        pass
    return 0.0


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "ingest.sh"
    out_file = workspace / "processed.log"
    feed_file = workspace / "feed.raw"

    if not script.exists():
        fail("Missing required script: ingest.sh")

    if not feed_file.exists():
        fail("Missing test fixture: feed.raw")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing memory complexity in ingest.sh...")
    if "+=(" in active_code or "declare -a" in active_code:
        fail("Memory bloat detected! Buffering streaming datasets into shell arrays causes OOM kills.")

    if out_file.exists():
        out_file.unlink()

    # 2. Execution & Memory RSS profiling
    log("Executing streaming ingestion and profiling memory RSS...")
    proc = subprocess.Popen(
        ["bash", str(script)],
        cwd=str(workspace),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    peak_rss = 0.0
    t0 = time.time()
    while proc.poll() is None and (time.time() - t0) < 5.0:
        rss = get_peak_rss_mb(proc.pid)
        if rss > peak_rss:
            peak_rss = rss
        time.sleep(0.01)

    stdout, stderr = proc.communicate(timeout=2.0)
    if proc.returncode != 0:
        fail(f"ingest.sh failed with exit code {proc.returncode}. Stderr: {stderr.strip()}")

    # 3. Validation
    if not out_file.exists():
        fail("processed.log was not created.")

    records_count = sum(1 for _ in out_file.open("r", encoding="utf-8"))
    if records_count != 5000:
        fail(f"Expected 5,000 processed records, found {records_count}")

    if peak_rss > 15.0:
        fail(f"MEMORY CEILING EXCEEDED: Peak RSS reached {peak_rss:.2f}MB (threshold: 15.0MB). Stream directly without buffering.")

    log(f"Processed 5,000 records with constant streaming memory: Peak RSS {peak_rss:.2f}MB (cgroup safe < 15MB).")
    print("\n  [PASS] O(1) STREAMING MEMORY COMPLEXITY VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
