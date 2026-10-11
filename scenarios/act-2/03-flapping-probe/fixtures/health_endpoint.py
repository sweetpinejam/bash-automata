#!/usr/bin/env python3
"""Simulated microservice health endpoint with transient faults."""
import os
import sys
from pathlib import Path

STATE_FILE = Path("probe_counter.txt")
MODE = os.environ.get("PROBE_MODE", "transient")

count = 0
if STATE_FILE.exists():
    try:
        count = int(STATE_FILE.read_text(encoding="utf-8").strip())
    except Exception:
        count = 0

count += 1
STATE_FILE.write_text(str(count), encoding="utf-8")

if MODE == "outage":
    # Complete outage: always fail
    print(f"CYCLE {count}: 500 Internal Server Error (Outage)", file=sys.stderr)
    sys.exit(1)

# Transient fault mode: cycles 3 and 7 experience temporary blips
if count in (3, 7):
    print(f"CYCLE {count}: 503 Service Unavailable (Transient Blip)", file=sys.stderr)
    sys.exit(1)

print(f"CYCLE {count}: 200 OK (Healthy)")
sys.exit(0)
