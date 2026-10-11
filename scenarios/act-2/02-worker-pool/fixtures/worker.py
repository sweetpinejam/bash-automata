#!/usr/bin/env python3
"""Simulated background task executor with variable duration."""
import sys
import time
from pathlib import Path

if len(sys.argv) < 2:
    sys.exit(1)

item = sys.argv[1]

# Stagger task durations: task_01 is slow (0.08s), others are fast (0.015s)
if "slow" in item:
    time.sleep(0.08)
else:
    time.sleep(0.015)

with open("processed.log", "a", encoding="utf-8") as f:
    f.write(f"PROCESSED: {item}\n")

sys.exit(0)
