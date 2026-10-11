#!/usr/bin/env python3
"""High-speed metrics reader and telemetry validator polling from shared memory."""
import os
import sys
import time
from pathlib import Path


def log(msg: str):
    print(f"  [CONSUMER] {msg}", flush=True)


def main():
    default_path = "/dev/shm/telemetry_bus.dat"
    shm_path = Path(sys.argv[1] if len(sys.argv) > 1 else default_path)

    log(f"Subscribing to shared memory ring buffer at {shm_path}...")
    target_frames = 100
    frames_read = 0
    last_frame_id = -1
    t0 = time.time()
    deadline = t0 + 4.0

    while frames_read < target_frames and time.time() < deadline:
        if shm_path.exists():
            try:
                raw_data = shm_path.read_text(encoding="utf-8").strip()
                # Parse format: FRAME_<id> ...
                if raw_data.startswith("FRAME_"):
                    parts = raw_data.split()
                    frame_tag = parts[0]
                    frame_num = int(frame_tag.split("_")[1])
                    if frame_num != last_frame_id:
                        frames_read += 1
                        last_frame_id = frame_num
            except (ValueError, IndexError, OSError):
                # File being rewritten concurrently; retry in next iteration
                pass
        time.sleep(0.005)

    duration = time.time() - t0
    rate = frames_read / max(duration, 0.001)

    if frames_read < target_frames:
        print(
            f"  [CONSUMER-ERROR] Read only {frames_read}/{target_frames} frames from {shm_path} (timed out after {duration:.2f}s)",
            file=sys.stderr,
        )
        sys.exit(1)

    log(f"Successfully consumed {frames_read} frames at {rate:.1f} frames/sec without storage I/O stalls.")
    sys.exit(0)


if __name__ == "__main__":
    main()
