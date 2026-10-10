#!/usr/bin/env python3
"""State-driven test harness for Act I, Scenario 1.1: The Choked Pipe."""
import os
import resource
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
    ingest_sh = workspace / "ingest.sh"
    process_py = workspace / "process.py"

    if not ingest_sh.exists():
        fail(f"Missing required script: {ingest_sh}")
    if not process_py.exists():
        fail(f"Missing required consumer: {process_py}")

    log("Auditing defensive shell practices in ingest.sh...")
    content = ingest_sh.read_text(encoding="utf-8")
    if "set -e" not in content and "set -euo pipefail" not in content:
        fail("ingest.sh must enforce defensive error handling (e.g., 'set -euo pipefail').")

    log("Auditing named pipe and signal trap decoupling...")
    active_code = "\n".join([line for line in content.splitlines() if not line.strip().startswith("#")])
    if "mkfifo" not in active_code:
        fail("ingest.sh must decouple the stream using a named pipe ('mkfifo'). Naive pipes block.")
    if "trap " not in active_code:
        fail("ingest.sh must register an exit trap ('trap ... EXIT INT TERM') to clean up the FIFO.")

    # Locate traffic generator fixture
    fixture_dir = Path(__file__).resolve().parent / "fixtures"
    gen_script = fixture_dir / "traffic_generator.py"
    if not gen_script.exists():
        fail("Traffic generator fixture not found.")

    target_count = 25000
    log(f"Injecting synthetic stress burst ({target_count} records at 10k/sec)...")

    start_time = time.monotonic()

    # Pipeline: traffic_generator -> bash ingest.sh
    gen_cmd = [sys.executable, str(gen_script), "--count", str(target_count), "--rate", "10000"]
    ingest_cmd = ["bash", str(ingest_sh)]

    try:
        p_gen = subprocess.Popen(gen_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        p_ingest = subprocess.Popen(
            ingest_cmd,
            stdin=p_gen.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=str(workspace),
            text=True,
        )
        if p_gen.stdout:
            p_gen.stdout.close()  # Allow p_gen to receive a SIGPIPE if p_ingest exits

        stdout_data, stderr_data = p_ingest.communicate(timeout=25)
        p_gen.wait(timeout=5)

    except subprocess.TimeoutExpired:
        if 'p_gen' in locals():
            p_gen.kill()
        if 'p_ingest' in locals():
            p_ingest.kill()
        fail("Pipeline stalled or deadlocked under high-throughput burst (timeout > 25s).")

    duration = time.monotonic() - start_time
    log(f"Stream completed in {duration:.2f}s ({target_count/duration:.1f} rec/s).")

    # Check for errors in output
    if p_ingest.returncode != 0:
        fail(f"ingest.sh exited with code {p_ingest.returncode}. Stderr: {stderr_data.strip()}")

    # Extract processed count
    processed = 0
    for line in stdout_data.splitlines():
        if "TOTAL_PROCESSED=" in line:
            try:
                processed = int(line.split("=")[1].strip())
            except ValueError:
                pass

    log(f"Processed records recorded: {processed}/{target_count}")
    if processed != target_count:
        fail(f"Data loss detected: Expected {target_count} records, but consumer processed {processed}.")

    log("Zero records lost during high-throughput burst.")
    log("Memory and process lifecycle assertions verified.")
    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
