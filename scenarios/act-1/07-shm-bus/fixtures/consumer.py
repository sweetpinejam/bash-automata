#!/usr/bin/env python3
"""High-speed metrics reader polling from shared memory."""
import os
import sys
import time
from pathlib import Path

def main():
    shm_path = Path(sys.argv[1] if len(sys.argv) > 1 else "/dev/shm/telemetry_bus.dat")

    frames_read = 0
    t0 = time.time()
    while frames_read < 100 and (time.time() - t0) < 3.0:
        if shm_path.exists():
            try:
                data = shm_path.read_text(encoding="utf-8").strip()
                if data.startswith("FRAME_"):
                    frames_read += 1
            except Exception:
                pass
        time.sleep(0.005)

    if frames_read < 100:
        print(f"FAILED: Only read {frames_read} frames from {shm_path}", file=sys.stderr)
        sys.exit(1)

    print(f"SUCCESS: Read {frames_read} frames from shared memory.")
    sys.exit(0)

if __name__ == "__main__":
    main()
