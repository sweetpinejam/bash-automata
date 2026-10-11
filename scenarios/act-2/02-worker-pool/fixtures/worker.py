#!/usr/bin/env python3
"""Simulated background task executor with variable duration and structured telemetry."""
import argparse
import sys
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Worker execution unit.")
    parser.add_argument("item", help="Task item identifier")
    parser.add_argument("--output", "-o", default="processed.log", help="Output log file")
    args = parser.parse_args()

    item = args.item
    out_file = Path(args.output)

    # Stagger task durations: tasks with 'slow' take 0.08s, standard take 0.015s
    if "slow" in item:
        time.sleep(0.08)
    else:
        time.sleep(0.015)

    with open(out_file, "a", encoding="utf-8") as f:
        f.write(f"PROCESSED: {item}\n")

    sys.exit(0)


if __name__ == "__main__":
    main()
