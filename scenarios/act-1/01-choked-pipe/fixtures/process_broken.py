#!/usr/bin/env python3
"""Broken starter consumer with unbuffered string decoding and unbounded memory accumulation."""
import sys
import time

records = []

def main():
    # Naive line-by-line read causing CPU bottlenecks and GC pauses
    for line in sys.stdin:
        # Simulated slow processing
        records.append(line.strip())
        if len(records) % 1000 == 0:
            sys.stderr.write(f"Processed: {len(records)}\n")
            time.sleep(0.01)

    print(f"TOTAL_PROCESSED={len(records)}")

if __name__ == "__main__":
    main()
