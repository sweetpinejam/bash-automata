# Tactical Field Manual: The Shared Memory Bus (`/dev/shm` & RAM Disks)

> **POSIX & Linux Systems Engineering Handbook**  
> **Subsystem**: Linux Virtual Filesystem Switch (VFS), `tmpfs` Kernel Filesystem, and Inter-Process Communication (IPC)

---

## 1. Architectural Mental Model: Storage Latency vs Memory Bus Bandwidth

In high-frequency event streaming, metric telemetry, and real-time state synchronization, processes require low latency and high bandwidth:

| Storage Medium | Typical Access Latency | Bandwidth Throughput | Kernel Subsystem Involved |
| :--- | :--- | :--- | :--- |
| **L1 / L2 / L3 CPU Caches** | 1 – 15 nanoseconds | Terabytes / sec | CPU Hardware Memory Controller |
| **System DRAM (RAM)** | 50 – 100 nanoseconds | 20 – 60 GB / sec | Linux Virtual Memory / Page Allocator |
| **NVMe Flash SSD (Direct)** | 20 – 100 microseconds | 2 – 7 GB / sec | Block Layer, NVMe Driver, PCIe Bus |
| **Filesystem on SSD (ext4/XFS)** | 100 µs – 10 milliseconds | 500 MB – 3 GB / sec | VFS, Journaling (`jbd2`), Page Cache Dirty Writeback |

```
Standard Disk Path (./workspace/metrics.dat):
Process ──▶ VFS ──▶ Ext4 Driver ──▶ Journal Commit (jbd2) ──▶ Block Layer ──▶ SSD
                      ▲ (Dirty Pages)
                      └──── Flushed by kernel flusher threads (pdflush/kworker)

Shared Memory RAM Path (/dev/shm/metrics.dat):
Process ──▶ VFS ──▶ tmpfs ──▶ System DRAM (Zero Storage I/O, Sub-microsecond latency)
```

### The Disk I/O Bottleneck

When a high-frequency daemon writes snapshots to disk (even SSDs):
1. Every write updates filesystem metadata (inodes, modification timestamps, directory entries).
2. The journaling layer (`jbd2` in ext4) logs metadata changes to the journal ring buffer before committing blocks.
3. If multiple write operations occur per millisecond, the kernel buffer pool marks pages dirty, triggering periodic I/O stalls (`iowait`) and causing real-time consumers to miss processing deadlines.

---

## 2. Kernel Mechanics: What is `/dev/shm`?

Linux implements the POSIX shared memory specification (`shm_open(3)`) using a specialized virtual filesystem: **`tmpfs`**, mounted by default at `/dev/shm`:

```bash
$ mount | grep shm
tmpfs on /dev/shm type tmpfs (rw,nosuid,nodev,noexec,relatime,size=8192k)
```

### Key Properties of `tmpfs`:
1. **Resident in Virtual Memory**: All inodes and data blocks in `tmpfs` reside directly in Linux kernel page cache memory (DRAM). Writes never issue SCSI/NVMe block requests to storage hardware.
2. **Transparent File Semantics**: Unlike POSIX IPC shared memory APIs that require C wrappers (`shm_open`, `ftruncate`, `mmap`), any standard Linux command or script (`echo`, `cat`, `dd`, `jq`, `python`) can read and write files in `/dev/shm` using normal file I/O operations (`open`, `read`, `write`, `close`).
3. **Sub-Microsecond Latency**: Data transfer between producer and consumer runs at DRAM bus speeds with zero disk queuing delay.

---

## 3. The Critical Danger: RAM Leaks in `tmpfs`

Because `/dev/shm` is backed by RAM, **files created in `/dev/shm` are not automatically reclaimed when a process exits.**

Unlike Unix domain sockets or anonymous pipes—which the Linux kernel destroys immediately once all file descriptors close—a file in `tmpfs` is a real filesystem directory entry:
- If a writer creates `/dev/shm/telemetry.dat` (e.g. 50 MB) and terminates without deleting it, **50 MB of physical system RAM remains locked forever** until the system reboots or the file is explicitly deleted (`unlink(2)`).
- In automated test runners or continuous deployments, leaked files in `/dev/shm` quickly trigger **`ENOSPC` (No space left on device)** or host Out-Of-Memory (OOM) killer terminations.

### The Defensive Exit Trap Contract

Any script allocating temporary memory nodes in `/dev/shm` must register an explicit cleanup trap:

```bash
BUS_FILE="/dev/shm/telemetry_bus_$$.dat"
MAIN_PID=$$

# Defensively unlink buffer upon ANY exit condition (normal, SIGINT, SIGTERM)
trap 'if [[ "$BASHPID" == "$MAIN_PID" ]]; then rm -f "$BUS_FILE"; fi' EXIT INT TERM
```

---

## 4. Production Gotchas & Container Environments

| Hazard | Cause | Prevention / Solution |
| :--- | :--- | :--- |
| **Container `ENOSPC`** | Docker and Kubernetes default the `/dev/shm` mount inside containers to **64 Megabytes** regardless of host RAM. | In Docker, launch with `--shm-size=512m` or `--ipc=host`. In Kubernetes, mount an `emptyDir` volume with `medium: Memory`. |
| **Path Collisions Across Services** | Multiple processes writing to the same static path (`/dev/shm/bus.dat`). | Isolate buffer paths using process IDs, usernames, or UUIDs: `/dev/shm/${USER}_bus_${BASHPID}.dat`. |
| **Torn Reads Under Concurrency** | Consumer reads the buffer while writer is mid-write. | Write to a temporary link and rename atomically (`mv -T`), or use POSIX file locking (`flock(1)` / `flock(2)`). |
| **Memory Pressure & Swapping** | Under intense host memory pressure, the Linux kernel can page out `tmpfs` memory to swap partitions. | If strict real-time guarantees are required, lock memory pages via `mlockall(2)` or disable swap. |

---

## 5. Curated Reading List & Authoritative Manuals

Study these authoritative system documentation sources to master Linux shared memory:

1. **`man 7 shm_overview`**
   - The Linux Programmer's Manual on POSIX Shared Memory API semantics, lifecycle, and filesystem namespace mapping.
2. **`man 5 tmpfs`**
   - The Linux kernel documentation on `tmpfs` mount options (`size`, `nr_blocks`, `mode`), page allocation, and swap interaction.
3. **`man 3 shm_open` & `man 3 shm_unlink`**
   - The C library standard interfaces for creating and removing shared memory objects under `/dev/shm`.
4. **`man 2 mmap`**
   - Understanding virtual memory page mapping, `MAP_SHARED` vs `MAP_PRIVATE`, and zero-copy data exchange.
5. **Brendan Gregg: *Systems Performance: Enterprise and the Cloud***
   - *Chapter 7: Memory* (Virtual Memory, Page Cache, tmpfs Architecture)
   - *Chapter 9: Disks* (Storage Latency, I/O Wait, Block Layer Queuing)
6. **The Linux Programming Interface (TLPI) by Michael Kerrisk**
   - *Chapter 54: POSIX Shared Memory* — In-depth exploration of kernel object lifetimes, permission bits, and `/dev/shm` directory entry cleanup.

---

## 6. Self-Assessment Checklist

Test your understanding of Linux shared memory:
- [ ] How does writing to `/dev/shm/data.dat` differ from writing to `./workspace/data.dat` in terms of kernel system calls and physical device I/O?
- [ ] Why do files left behind in `/dev/shm` cause RAM leaks while closed Unix pipes do not?
- [ ] What is the default size limit of `/dev/shm` inside a standard Docker container, and what flag overrides it?
- [ ] What happens to the contents of `/dev/shm` when the physical host reboots?
- [ ] Why should cleanup traps always check `[[ "$BASHPID" == "$MAIN_PID" ]]` in scripts that spawn background subshells?
