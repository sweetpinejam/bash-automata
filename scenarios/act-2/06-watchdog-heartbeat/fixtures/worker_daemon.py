#!/usr/bin/env python3
"""Simulated worker daemon with intermittent freeze."""
import os
import signal
import sys
import time
from pathlib import Path

HEARTBEAT_FILE = Path("heartbeat.ts")
PID_FILE = Path("worker.pid")

running = True


def handle_term(signum, frame):
    global running
    running = False
    if PID_FILE.exists():
        PID_FILE.unlink()
    sys.exit(0)


signal.signal(signal.SIGTERM, handle_term)
signal.signal(signal.SIGINT, handle_term)

PID_FILE.write_text(str(os.getpid()), encoding="utf-8")

# Normal heartbeats for 3 cycles
for _ in range(3):
    HEARTBEAT_FILE.write_text(f"{int(time.time())}\n", encoding="utf-8")
    time.sleep(0.05)

# If TRIGGER_FREEZE is active, enter deadlock freeze
if os.environ.get("TRIGGER_FREEZE", "true") == "true":
    while running:
        # Silently hangs without updating heartbeat
        time.sleep(1)

# Normal mode: keep updating heartbeat
while running:
    HEARTBEAT_FILE.write_text(f"{int(time.time())}\n", encoding="utf-8")
    time.sleep(0.05)
