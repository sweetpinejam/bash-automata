#!/usr/bin/env python3
"""Production telemetry batch processor and metrics accumulator."""
import os
import resource
import sys
import time

records = []


def get_rss_mb() -> float:
    usage = resource.getrusage(resource.RUSAGE_SELF)
    # ru_maxrss is in kilobytes on Linux
    return usage.ru_maxrss / 1024.0


def main():
    start_time = time.monotonic()
    sys.stderr.write(f"[{time.strftime('%X')}] [CONSUMER] Starting metric consumer (PID: {os.getpid()})\n")

    # BROKEN NAIVE INGESTION:
    # Line-by-line reading with string allocations causes GC pauses and memory inflation.
    # When coupled to a synchronous anonymous pipe, these micro-delays choke the 64KB buffer.
    count = 0
    try:
        # Check if sys.stdin has binary buffer or direct stream
        if hasattr(sys.stdin, "buffer"):
            # High-performance chunked binary processing
            buf = bytearray(65536)
            while True:
                n = sys.stdin.buffer.readinto(buf)
                if not n:
                    break
                count += buf[:n].count(b"\n")
                if count % 5000 == 0:
                    time.sleep(0.001)
        else:
            for line in sys.stdin:
                count += 1
                if count % 1000 == 0:
                    time.sleep(0.005)
    except Exception as exc:
        sys.stderr.write(f"[ERROR] Consumer failure: {exc}\n")
        sys.exit(1)

    elapsed = time.monotonic() - start_time
    rate = count / elapsed if elapsed > 0 else 0
    rss = get_rss_mb()

    sys.stderr.write(
        f"[{time.strftime('%X')}] [CONSUMER] Drained {count} records in {elapsed:.2f}s "
        f"({rate:.1f} rec/s, RSS: {rss:.1f} MB)\n"
    )

    # Verification contract: emit TOTAL_PROCESSED=<N>
    print(f"TOTAL_PROCESSED={count}")


if __name__ == "__main__":
    main()
