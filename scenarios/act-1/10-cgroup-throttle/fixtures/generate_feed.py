#!/usr/bin/env python3
"""High-volume telemetry feed generator for cgroup memory stress tests."""
import argparse
import sys
from pathlib import Path


def generate_feed(target_path: Path, record_count: int, padding_size: int = 40):
    padding = "X" * padding_size
    with open(target_path, "w", encoding="utf-8") as f:
        for i in range(1, record_count + 1):
            f.write(f"RECORD_ID={i:06d} PAYLOAD=DATA_{i:06d}_{padding}\n")


def main():
    parser = argparse.ArgumentParser(description="Generate mock telemetry event feed.")
    parser.add_argument("--output", "-o", default="feed.raw", help="Output file path")
    parser.add_argument("--count", "-n", type=int, default=5000, help="Number of records")
    args = parser.parse_args()

    out_file = Path(args.output)
    generate_feed(out_file, args.count)


if __name__ == "__main__":
    main()
