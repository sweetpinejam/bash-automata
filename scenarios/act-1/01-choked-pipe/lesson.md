# Tactical Field Manual: The Choked Pipe (Kernel Pipes vs Named FIFOs)

## 1. The Architecture (Why Naive Pipes Stall Under Load)
When you connect two programs using an anonymous pipe (`producer | consumer`), the operating system kernel allocates a fixed-size circular memory buffer (typically **64 KB** on modern Linux kernels).

```
  [ Producer ] ──( stdout )──▶ [ Linux Pipe Buffer: 64 KB ] ──( stdin )──▶ [ Consumer ]
```

When data floods in faster than the consumer can process (e.g. 5,000 metrics/sec):
1. The 64KB kernel buffer fills to capacity.
2. The kernel puts the producer process to sleep via standard blocking I/O (`write()` blocks until space opens).
3. If the consumer pauses (for instance, during a Python garbage collection cycle or network flush), the entire pipeline locks up.
4. Latency spikes and upstream buffers overrun, dropping telemetry packets.

---

## 2. The Solution: Decoupled Ingestion via Named Pipes (`mkfifo`)
A Named Pipe (**FIFO**) is a special filesystem node created via `mkfifo`:
```bash
FIFO="/tmp/telemetry_$$.fifo"
mkfifo "$FIFO"
trap 'rm -f "$FIFO"' EXIT INT TERM
```

Unlike anonymous pipes, named pipes allow:
- **Independent lifecycle**: The ingestion process can run as a detached background worker.
- **Multiple readers/writers**: Several workers can feed into a single consumer.
- **Non-blocking binary streaming**: Python consumers can read fixed-size binary chunks (`sys.stdin.buffer.readinto`) directly from the descriptor without line-splitting overhead.

---

## 3. Python High-Throughput Stream Contract
In standard Python, `for line in sys.stdin:` does line buffering and UTF-8 string decoding, causing huge garbage collection overhead.
For maximum throughput under 64MB RAM:
```python
import sys

# Read raw bytes in 64KB blocks matching kernel pipe page size
buf = bytearray(65536)
while True:
    n = sys.stdin.buffer.readinto(buf)
    if n == 0:
        break
    # Process memory slice directly
    chunk = memoryview(buf)[:n]
```

---

## 4. Recommended Reading List
* `man 7 pipe` (Linux kernel pipe capacity and packet atomicity)
* `man 3 mkfifo` (Creating FIFO special files)
* Brendan Gregg: Systems Performance (Chapter 6: File Systems & Descriptors)

---

## 5. Mission Objective
Refactor `ingest.sh` and `process.py` in your workspace. Replace the naive pipe with an asynchronous named pipe (`mkfifo`) and chunked binary batching. Ensure zero records are lost across 10,000 packets and peak RAM stays strictly under 64MB.
