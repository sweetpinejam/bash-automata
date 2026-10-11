# Tactical Field Manual: The Shared Memory Bus (`/dev/shm` & RAM Disks)

## 1. The Architecture (Why Physical Disk I/O Bottlenecks IPC)
When two processes on the same Linux host exchange messages by writing and reading files in a standard workspace folder:
1. Every write system call goes through the kernel Virtual Filesystem (VFS).
2. The journaling filesystem (ext4 / XFS) must record metadata blocks to the physical drive (NVMe / SSD).
3. Under high frequency (e.g. 10,000 writes/sec), storage controllers queue requests, triggering **`iowait`** CPU stalls and premature flash drive wear.

---

## 2. The Solution: POSIX Shared Memory (`/dev/shm`)
Linux mounts an in-memory **tmpfs filesystem** directly at **`/dev/shm`**:
- Reads and writes to `/dev/shm` **never touch physical storage**.
- Operations operate at native **RAM bus speeds** (10 to 30 GB/s) with sub-microsecond latency.
- Any process with file read/write permissions can open, poll, and memory-map files in `/dev/shm`.

```
  Process A (Bash Writer) ──( RAM Write )──▶ [ /dev/shm/bus.dat ] ──( RAM Read )──▶ Process B (Python Reader)
                                                     │
                                            (Kernel tmpfs in RAM)
```

---

## 3. The Responsibility: Cleaning Up `/dev/shm`
Because `/dev/shm` is stored in RAM, **files left behind in `/dev/shm` consume system memory indefinitely** until rebooted or deleted.
Always pair `/dev/shm` files with an explicit `EXIT` trap:

```bash
SHM_FILE="/dev/shm/bus_$$.dat"
trap 'rm -f "$SHM_FILE"' EXIT INT TERM
```

---

## 4. Recommended Reading List
* `man 7 shm_overview` (Overview of POSIX Shared Memory)
* `man 5 tmpfs` (Linux virtual in-memory filesystem)
* Linux Performance: Brendan Gregg on Memory & Storage Latencies

---

## 5. Mission Objective
Edit `writer.sh` in your sandbox. Relocate the telemetry stream file to `/dev/shm/telemetry_bus.dat` and register an EXIT trap to unlink it upon termination.
Verify with `[4] Run State Verification`.
