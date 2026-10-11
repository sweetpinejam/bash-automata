#!/usr/bin/env python3
"""State assertion test for Mission 2.09: The Advisory Lock Contest."""
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
    writer_sh = workspace / "cron_writer.sh"
    multi_sh = workspace / "multi_runner.sh"
    dump_file = workspace / "metrics_dump.tsv"

    if not writer_sh.exists():
        fail("Missing required script: cron_writer.sh")

    content = writer_sh.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    log("Auditing kernel advisory lock utilization in cron_writer.sh...")
    if "flock" not in active_code:
        fail("cron_writer.sh must protect writes using kernel 'flock' to prevent file interleaving.")

    if dump_file.exists():
        dump_file.unlink()

    log("Executing 4 concurrent cron writers in contention...")
    proc = subprocess.run(
        ["bash", str(multi_sh)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=10,
    )

    if proc.returncode != 0:
        fail(f"multi_runner.sh failed (exit code {proc.returncode}).\nStderr: {proc.stderr.strip()}")

    log("Auditing integrity and atomicity of metrics_dump.tsv...")
    if not dump_file.exists():
        fail("metrics_dump.tsv was not generated!")

    lines = [l.strip() for l in dump_file.read_text(encoding="utf-8").splitlines() if l.strip()]
    log(f"Total lines in output file: {len(lines)}/120 (4 workers x 10 records x 3 lines)")

    if len(lines) != 120:
        fail(f"Expected 120 lines, got {len(lines)}. Data dropped or truncated!")

    # Check for torn rows / interleaving
    torn_rows = 0
    i = 0
    while i < len(lines):
        if lines[i] != "START_ROW":
            torn_rows += 1
            i += 1
            continue
        if i + 1 >= len(lines) or not lines[i + 1].startswith("worker="):
            torn_rows += 1
            i += 1
            continue
        if i + 2 >= len(lines) or lines[i + 2] != "END_ROW":
            torn_rows += 1
            i += 1
            continue
        i += 3

    log(f"Torn / interleaved rows detected: {torn_rows}")
    if torn_rows > 0:
        fail(f"Race condition detected! Found {torn_rows} torn or interleaved rows in metrics_dump.tsv.")

    log("ALL ADVISORY LOCK MUTEX ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
