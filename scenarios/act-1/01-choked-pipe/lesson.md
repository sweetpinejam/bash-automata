# Tactical Field Manual: The Choked Pipe (Kernel Pipes, Named FIFOs & Zero-Loss Ingest)

## 1. Systems Mental Model: The Linux Pipe Buffer & Kernel Backpressure
In POSIX operating systems, when you connect two processes with a standard anonymous pipe:
```bash
producer | consumer
```
The Linux kernel does not create an infinite file on disk. Instead, the Virtual File System (VFS) allocates a circular in-memory buffer ring composed of kernel memory pages.
* On Linux 2.6.35 and newer, the default pipe capacity is strictly **64 KB** (16 pages of 4096 bytes each).
* You can inspect your host kernel's maximum permissible pipe limit with:
  ```bash
  cat /proc/sys/fs/pipe-max-size
  ```

```
┌──────────────┐                       ┌────────────────────────┐                       ┌──────────────┐
│   PRODUCER   │ ──( write(2) calls )─▶│   KERNEL PIPE BUFFER   │──( read(2) calls )───▶│   CONSUMER   │
│ (ingest.sh)  │                       │   (Ring Buffer: 64KB)  │                       │ (process.py) │
└──────────────┘                       └────────────────────────┘                       └──────────────┘
```

### The Anatomy of a Choked Pipe:
1. **The Influx Burst**: A telemetry producer transmits metrics at high velocities (e.g., 5,000 to 10,000 metrics/sec).
2. **Buffer Saturation**: If the consumer process pauses for even a fraction of a second—due to Python garbage collection, memory allocations, or batch flushes—the 64KB kernel buffer fills completely in less than 20 milliseconds.
3. **The Uninterruptible Stall (`write(2)` Blocking)**:
   When a pipe buffer is full, subsequent `write()` system calls by the producer **block unconditionally**. The operating system kernel puts the producer process into the `D` state (uninterruptible sleep waiting on I/O).
4. **Cascading Failure**: The upstream producer stops reading from network sockets or message queues. Upstream network buffers overflow, packets are dropped, latency spikes, and telemetry is permanently lost.

---

## 2. Syntax & Mechanism Comparison: Pipeline Architectures

| Characteristic | Anonymous Pipe (`cmd1 \| cmd2`) | Named Pipe / FIFO (`mkfifo`) | Unix Domain Socket (`AF_UNIX`) |
| :--- | :--- | :--- | :--- |
| **Filesystem Presence** | None (ephemeral kernel inode) | Inode in directory table (`S_IFIFO`) | Inode in directory table (`S_IFSOCK`) |
| **Process Relationship** | Must share common parent shell | Any unrelated processes with permissions | Any unrelated processes with permissions |
| **Buffer Mechanism** | Kernel circular buffer (64KB) | Kernel circular buffer (64KB) | Kernel socket buffer (`SO_RCVBUF`) |
| **Lifecycle Control** | Dies when either process exits | Persists in filesystem until `rm`/`unlink` | Persists in filesystem until unlinked |
| **Concurrency Model** | Strictly 1-to-1 synchronous coupling | Decoupled background producers & readers | Full bi-directional client/server multiplexing |

---

## 3. Systems Solution: Decoupled Ingestion via Named Pipes (`mkfifo`)

A Named Pipe (FIFO) is a special filesystem node created using `mkfifo(3)`:
```bash
FIFO_PATH="/tmp/telemetry_$$.fifo"
mkfifo "$FIFO_PATH"
```
Even though a FIFO appears in `ls -l` with a `p` file type flag (`prw-r--r--`), **it consumes zero bytes of disk storage**. All data transfers remain pure in-memory kernel operations.

### The Decoupled Asynchronous Lifecycle:
```bash
# 1. Register emergency exit trap BEFORE opening descriptors
trap 'rm -f "$FIFO_PATH"' EXIT INT TERM

# 2. Spawn the downstream consumer in the BACKGROUND reading from the FIFO
python3 process.py < "$FIFO_PATH" &
CONSUMER_PID=$!

# 3. Stream upstream data directly into the FIFO
cat > "$FIFO_PATH"

# 4. Wait cleanly for downstream consumer to drain and terminate
wait "$CONSUMER_PID"
```

### Why Spawning the Reader First is Mandatory:
In the POSIX standard, opening a FIFO for writing (`O_WRONLY`) **blocks until another process opens the same FIFO for reading (`O_RDONLY`)**.
* If you run `cat > "$FIFO"` *before* launching the background consumer, your script freezes permanently in a mutual deadlock!
* Spawning the background reader (`python3 ... < "$FIFO" &`) ensures the read descriptor is open, allowing the writer to immediately stream bytes without hanging.

---

## 4. The Python High-Throughput Stream Contract

In Python, naive stream processing looks like this:
```python
# 💥 THE SLOW TEXT-MODE TRAP:
for line in sys.stdin:
    records.append(line.strip())  # Allocates str objects, decodes UTF-8, triggers GC
```
When ingesting tens of thousands of telemetry metrics:
1. `sys.stdin` is wrapped in an `io.TextIOWrapper`, which performs line-buffering and UTF-8 validation on every line.
2. Appending thousands of string objects causes massive heap fragmentation and frequent GC pauses.

### Production High-Throughput Binary Ingestion:
To process high-frequency streams under strict memory ceilings (<64MB RSS):
```python
import sys

# Direct access to underlying binary buffer (io.BufferedReader)
raw_stream = sys.stdin.buffer

# 64KB bytearray matching kernel pipe capacity
buf = bytearray(65536)
record_count = 0

while True:
    n = raw_stream.readinto(buf)
    if n == 0:
        break
    # Count newline delimiters directly in raw bytes without string allocations:
    record_count += buf[:n].count(b"\n")

print(f"TOTAL_PROCESSED={record_count}")
```
* `readinto(buf)` reuses the exact same 64KB memory allocation on every iteration (zero memory churn).
* `buf[:n].count(b"\n")` scans the buffer at native C speed using CPU vector instructions (`memchr`).
* Peak memory remains under **15 MB RSS** regardless of whether 10,000 or 10,000,000 metrics flow through.

---

## 5. Architectural Diagram: Decoupled Ingestion Flow

```
                      [ Upstream Traffic Burst ]
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │  telemetry_forwarder.sh   │
                    │   - Validates CLI flags   │
                    │   - Registers EXIT trap   │
                    │   - Allocates mkfifo      │
                    └─────────────┬─────────────┘
                                  │
                  ┌───────────────┴───────────────┐
                  ▼                               ▼
    [ Spawn Consumer in Background ]     [ Stream Standard Input ]
    python3 process.py < "$FIFO" &        cat > "$FIFO"
                  │                               │
                  └───────────────┬───────────────┘
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │     NAMED PIPE (FIFO)     │
                    │    Kernel Ring Buffer     │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │      batch_processor      │
                    │  - sys.stdin.buffer       │
                    │  - Zero-copy readinto     │
                    │  - RSS strictly < 64MB    │
                    │  - TOTAL_PROCESSED=<N>    │
                    └───────────────────────────┘
```

---

## 6. Real-World Gotchas & Pitfalls

1. **The Inode Leak Zombie**:
   If a script creating a named pipe crashes or is killed by `SIGTERM` without an `EXIT` trap, the named pipe stays in `/tmp` permanently. Future runs attempting `mkfifo` fail with `EEXIST: File exists`.
2. **The SIGPIPE Signal (Signal 13)**:
   If the downstream consumer process crashes or exits while the producer is still writing to the pipe, the operating system kernel sends `SIGPIPE` to the producer. By default, `SIGPIPE` terminates the producer immediately.
3. **Pipe Buffer Sizing via `fcntl`**:
   While the default pipe capacity is 64KB, Linux allows unprivileged processes to expand pipe capacity up to the value in `/proc/sys/fs/pipe-max-size` (typically 1MB) using `fcntl(fd, F_SETPIPE_SZ, size)`.

---

## 7. Curated Reading & Reference Guide

* **`man 7 pipe`**: The foundational Linux manual on pipe capacity, packet atomicity (`PIPE_BUF` 4096-byte atomic guarantee), and `O_NONBLOCK` semantics.
* **`man 3 mkfifo`**: C library specification for creating FIFO special files, file permission modes, and error conditions (`EEXIST`, `ENOSPC`).
* **`man 2 fcntl`**: Review `F_SETPIPE_SZ` and `F_GETPIPE_SZ` to understand how kernel pipe buffer capacities are inspected and adjusted at runtime.
* **POSIX IEEE Std 1003.1-2017 (Volume System Interfaces)**: Section 3.161 (*FIFO Special File*) and Section 2.9.1 (*Pipes and FIFOs*).
* **Linux Kernel Documentation (`/proc/sys/fs/pipe-max-size`)**: Explains administrative controls on memory allocation for circular pipe buffers.
* **Brendan Gregg: *Systems Performance: Enterprise and the Cloud***: Chapter 6 (*File Systems and Storage*) — Section on file descriptors, buffering, and VFS caches.
* **Python Documentation (`io.BufferedReader` & `sys.stdin.buffer`)**: Deep dive on why raw byte streaming avoids `TextIOWrapper` decoding bottlenecks.

---

## 8. Self-Assessment Checklist
Before modifying your scripts:

1. **Why does an anonymous pipe `producer | consumer` stall when the consumer pauses?**
   * *Answer*: Because the Linux kernel circular buffer is capped at 64KB; once full, `write(2)` blocks until the consumer reads data.
2. **Why does running `cat > fifo` before launching `python3 < fifo &` cause an immediate freeze?**
   * *Answer*: In POSIX shells, opening a FIFO for writing blocks until another process opens it for reading. Launching the reader in the background first prevents deadlock.
3. **Why does `sys.stdin.buffer.readinto()` keep memory usage under 64MB RSS compared to `for line in sys.stdin`?**
   * *Answer*: It reuses a pre-allocated fixed-size binary buffer, avoiding string object creation, UTF-8 parsing, and garbage collection churn.
4. **Why must named pipes be cleaned up with `trap 'rm -f "$FIFO"' EXIT INT TERM`?**
   * *Answer*: Because named pipes are real filesystem nodes that persist across process termination and will cause `EEXIST` errors on subsequent runs if not unlinked.
5. **What signal does the kernel send to a process that writes to a pipe with no active readers?**
   * *Answer*: `SIGPIPE` (Signal 13), which terminates the writing process unless caught or ignored.

---

## 9. Mission Objectives
Refactor `ingest.sh` and `process.py` into a high-throughput, decoupled telemetry ingestion subsystem:
1. In `ingest.sh`:
   - Enable strict defensive execution (`set -euo pipefail`).
   - Create a uniquely named FIFO: `FIFO_PATH="./stream_$$.fifo"`.
   - Register a cleanup trap to guarantee the FIFO is unlinked on `EXIT`, `INT`, and `TERM`.
   - Spawn `process.py` in the background reading from the FIFO.
   - Stream standard input directly into the FIFO and wait for the consumer process to exit.
2. In `process.py`:
   - Read high-velocity binary data using `sys.stdin.buffer.readinto()` or raw byte chunking.
   - Count all newline-delimited telemetry records without dropping packets.
   - Maintain peak resident memory (RSS) strictly below 64MB.
   - Emit `TOTAL_PROCESSED=<count>` to stdout upon completion.
