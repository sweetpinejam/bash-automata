#!/usr/bin/env python3
"""Fast state-driven verification for Mission 1.09: The Unbuffered Stream."""
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
    script = workspace / "pipeline.sh"
    stream_file = workspace / "events.stream"

    if not script.exists():
        fail("Missing required script: pipeline.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing line-buffering configurations in pipeline.sh...")
    if "--line-buffered" not in active_code and "stdbuf -oL" not in active_code and "stdbuf" not in active_code:
        fail("Missing line buffering enforcement ('--line-buffered' or 'stdbuf -oL').")

    if stream_file.exists():
        stream_file.unlink()

    # 2. Execution & Streaming latency audit
    log("Launching live telemetry pipeline and measuring streaming flush latency...")
    proc = subprocess.Popen(
        ["bash", str(script)],
        cwd=str(workspace),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    t0 = time.time()
    first_event_latency = None
    while proc.poll() is None and (time.time() - t0) < 3.0:
        if stream_file.exists() and stream_file.stat().st_size > 0:
            if first_event_latency is None:
                first_event_latency = time.time() - t0
        time.sleep(0.01)

    proc.wait(timeout=2.0)
    if proc.returncode != 0:
        fail(f"pipeline.sh failed with exit code {proc.returncode}.")

    # 3. Validation
    if not stream_file.exists():
        fail("events.stream was not generated.")

    lines = [l for l in stream_file.read_text().splitlines() if l.strip()]
    if len(lines) != 10:
        fail(f"Expected 10 streamed events, found {len(lines)}")

    log(f"All 10 events streamed. First event arrived in {first_event_latency:.3f}s (line-buffered).")
    print("\n  [PASS] UNBUFFERED STREAMING / LINE-BUFFERING CONTRACT VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
