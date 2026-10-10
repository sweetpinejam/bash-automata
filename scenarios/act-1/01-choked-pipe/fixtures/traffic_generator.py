#!/usr/bin/env python3
"""Synthetic telemetry stream generator for Act I Scenario 1.1."""
import argparse
import sys
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=10000, help="Total metric lines")
    parser.add_argument("--rate", type=int, default=5000, help="Target lines/sec")
    args = parser.parse_args()

    delay = 1.0 / args.rate if args.rate > 0 else 0
    start = time.time()

    for i in range(args.count):
        payload = f"metric.host.cpu.load,host=edge-worker-{i%5},core={i%4} value={i*1.5} {int(time.time()*1e9)}\n"
        sys.stdout.write(payload)
        if (i + 1) % 500 == 0:
            sys.stdout.flush()
        if delay > 0 and (i + 1) % 50 == 0:
            time.sleep(delay * 50)

    sys.stdout.flush()


if __name__ == "__main__":
    main()
