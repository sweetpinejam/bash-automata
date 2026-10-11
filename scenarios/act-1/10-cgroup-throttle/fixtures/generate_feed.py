#!/usr/bin/env python3
"""Generates test feed of 5,000 records."""
import sys
from pathlib import Path

def main():
    target = Path("feed.raw")
    with open(target, "w", encoding="utf-8") as f:
        for i in range(1, 5001):
            f.write(f"RECORD_ID={i:06d} PAYLOAD=DATA_{i:06d}_PADDING_BYTES_FOR_PRESSURE\n")

if __name__ == "__main__":
    main()
