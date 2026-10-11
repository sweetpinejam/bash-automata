# Tactical Field Manual 2.09: The Advisory Lock Contest

> **Incident Class**: Concurrent File Append Interleaving, Torn Records & Descriptor Mutexes  
> **Key Tooling**: `flock(1)` / `flock(2)`, Dedicated File Descriptors (`exec 200>`), Exclusive Locks (`-x`), POSIX Append Semantics

---

## 1. Incident Post-Mortem & Architecture Context

In distributed telemetry pipelines, multi-process batch orchestrators, and concurrent cron workers, multiple processes frequently write log messages, event streams, or TSV metrics to a centralized on-disk file:
```bash
# Process 1                         # Process 2
echo "START_ROW" >> dump.tsv        echo "START_ROW" >> dump.tsv
echo "metric=cpu val=88" >> dump.tsv echo "metric=mem val=42" >> dump.tsv
echo "END_ROW" >> dump.tsv          echo "END_ROW" >> dump.tsv
```

Although the operating system handles POSIX `O_APPEND` by seeking to the end of the file before each individual `write(2)` system call, **`O_APPEND` only guarantees atomicity for a single `write(2)` invocation**. 

When a multi-line structured record (such as an opening delimiter, header, data payload, and footer) requires multiple distinct shell `echo` or `printf` invocations, the kernel's CPU scheduler can preempt Process 1 between the first and second line. Process 2 runs its `write(2)` syscall, producing a corrupted interleaved file:
```tsv
START_ROW
START_ROW          <--- TORN ROW (Process 2 interleaved!)
metric=mem val=42
metric=cpu val=88
END_ROW
END_ROW
```
Downstream parsers (ETL pipelines, TSV readers, metric aggregators) fail with syntax errors or attribute the payload to the wrong worker.

To ensure that multi-line records remain contiguous, workers must establish **mutual exclusion (mutex)** around their entire multi-line write critical section using the Linux kernel's advisory locking subsystem (`flock`).

---

## 2. Kernel & POSIX Mental Models

### A. Advisory vs Mandatory File Locking
- **Advisory Locking (`flock(2)`)**: The operating system kernel maintains a record of which processes hold locks on an inode. However, it does not prevent uncooperative processes from writing to the file directly. All participating processes must explicitly query and respect the lock.
- **Mandatory Locking**: Historical UNIX supported mandatory locks (enforcing locks directly in `read(2)` and `write(2)`). In Linux, mandatory locking was fraught with kernel race conditions, denial-of-service vulnerabilities, and high performance overhead. It was deprecated in Linux 5.14 and completely removed in Linux 5.15. Production Linux systems rely strictly on advisory locking.

### B. Inodes, Open File Descriptions, and Descriptors
In Linux:
1. **File Descriptor Table**: Per-process table containing integer descriptors (`0`, `1`, `2`, `200`).
2. **Open File Description (`struct file`)**: System-wide kernel table tracking file offset, flags, and open status.
3. **Inode (`struct inode`)**: Represents the underlying file on the filesystem.

`flock(2)` locks are associated with the **open file description**:
- If a process opens a file descriptor and calls `flock(2)`, the lock persists across `fork(2)`. Both parent and child share the lock reference.
- **Automatic Kernel Cleanup**: If a process crashes or is killed by `SIGKILL`, the kernel closes all of its open file descriptors. When the reference count of the open file description drops to zero, the kernel **automatically releases the lock**. Unlike PID files or custom lock directories (`mkdir`), `flock` cannot leave permanently orphaned stale locks on process termination.

### C. Dedicated Descriptors vs Target Data File
A frequent mistake is running `flock` directly on the destination data file:
```bash
# ANTI-PATTERN: Truncates or races with other openers!
flock /var/log/data.tsv -c "echo ... >> /var/log/data.tsv"
```
Instead, production systems use a dedicated lock file (e.g. `metrics.lock`) opened on a persistent high-numbered file descriptor (`exec 200>"metrics.lock"`). This keeps the descriptor open across the lifecycle of the loop and avoids repeated open/close system calls.

---

## 3. Kernel Advisory Lock Architecture

```
  WORKER PROCESS A                                               WORKER PROCESS B
  (PID 4010)                                                    (PID 4011)
       │                                                             │
       ├─► exec 200>"metrics.lock"                                   │
       │                                                             ├─► exec 200>"metrics.lock"
       ├─► flock -x 200 ─────────────┐                               │
       │                             ▼                               │
       │                 ┌───────────────────────┐                   │
       │                 │   KERNEL INODE LOCK   │                   │
       │                 │   metrics.lock        │                   │
       │                 │   Holder: PID 4010    │                   │
       │                 └───────────────────────┘                   │
       │                             ▲                               │
       │   [IN CRITICAL SECTION]     │ (Contention)                  │
       │   echo "START_ROW"          └───────────────────────────────┼─► flock -x 200 (BLOCKED)
       │   echo "payload..."                                         │        ┆
       │   echo "END_ROW"                                            │        ┆ (Waiting on kernel queue)
       │                                                             │        ▼
       ├─► flock -u 200 ─────────────┐                               │
       │                             ▼                               │
       │                 ┌───────────────────────┐                   │
       │                 │   KERNEL INODE LOCK   │                   │
       │                 │   HOLDER: PID 4011    │◄──────────────────┘ [LOCK ACQUIRED!]
       │                 └───────────────────────┘                         │
       ▼                                                                   ▼
```

---

## 4. Syntax & Primitive Reference

| Primitive | Operation | Description |
| :--- | :--- | :--- |
| `exec 200>"$LOCK"` | Open Lock Descriptor | Opens `$LOCK` for writing on FD 200 in current shell |
| `flock -x 200` | Exclusive Lock | Blocks until exclusive write lock is acquired on FD 200 |
| `flock -s 200` | Shared Lock | Acquires shared read lock (multiple concurrent readers allowed) |
| `flock -n 200` | Non-blocking Probe | Fails immediately (`exit 1`) if lock is currently held |
| `flock -w 5 200` | Timed Lock | Waits up to 5 seconds before returning failure if held |
| `flock -u 200` | Unlock | Releases lock on FD 200 explicitly |
| `exec 200>&-` | Close Descriptor | Closes FD 200, decrementing kernel open file description count |

---

## 5. Production Implementation Gotchas

### 1. Descriptor Leak Across Background Subprocesses
When spawning background subshells (`&`) after opening FD 200, child subshells inherit file descriptor 200. If the main shell exits, the lock file remains open in the kernel as long as any child process holds FD 200.
Always close or set close-on-exec (`FD_CLOEXEC`) or explicitly close descriptors before spawning detached background tasks:
```bash
trap 'exec 200>&- 2>/dev/null || true' EXIT INT TERM
```

### 2. File Truncation Race Condition
Opening a file with `>` immediately truncates the file before `flock` can be invoked!
```bash
# DANGEROUS: File is truncated BEFORE flock executes!
exec 200>"shared_data.tsv"
flock -x 200
```
Always lock an independent lock file (`shared_data.tsv.lock`), or open the target file with append mode (`>>`) or read-write without truncation (`<>`).

### 3. NFS and Distributed Filesystem Incompatibilities
`flock(2)` semantics over NFS depends on the NFS version and kernel mount options (`nolock` vs `lock`). On NFS v2/v3 without `rpc.lockd`, `flock` calls can return success without actually synchronizing across different client nodes. For distributed cross-host locking, use distributed primitives (Redis Redlock, Consul, etcd, or database-backed advisory locks).

---

## 6. Self-Assessment Checklist

1. [ ] **Mutual Exclusion**: Is the entire multi-line record generation block wrapped between `flock -x` and `flock -u`?
2. [ ] **Descriptor Isolation**: Is a dedicated file descriptor (e.g. FD 200) used rather than conflicting with standard streams?
3. [ ] **Zero Data Corruption**: Does running 4+ concurrent workers produce 100% contiguous records without torn lines?
4. [ ] **Clean Resource Reaping**: Does the script close the file descriptor (`exec 200>&-`) and install an `EXIT` trap?
5. [ ] **Kernel Release Proof**: If a worker process is terminated abruptly, does the kernel automatically release its lock without manual lockfile removal?

---

## 7. Curated Reading List & References

- **Linux Manual Pages**:
  - `man 1 flock(1)` - Manage locks from shell scripts
  - `man 2 flock(2)` - Apply or remove an advisory lock on an open file
  - `man 2 fcntl(2)` - File control options (POSIX record locking: `F_SETLK`, `F_SETLKW`)
  - `man 2 open(2)` - Open and possibly create a file (`O_APPEND` concurrency characteristics)
- **POSIX IEEE Std 1003.1-2017**:
  - `File Locking Specifications: fcntl record locking`
  - `Shell Command Language: Section 2.7 (Redirection - Opening File Descriptors)`
- **The Linux Programming Interface (TLPI) by Michael Kerrisk**:
  - *Chapter 55: File Locking* (In-depth analysis of `flock(2)`, `fcntl(2)` record locks, interaction with `fork(2)` and `execve(2)`)
  - *Chapter 5: File I/O: Further Details* (File descriptors vs open file descriptions vs inodes)
- **Systems Performance & Storage Literature**:
  - *Brendan Gregg, "Systems Performance: Enterprise and the Cloud"* (Filesystem contention and locking overhead)
  - *W. Richard Stevens, Stephen A. Rago, "Advanced Programming in the UNIX Environment" (APUE)* - Chapter 14: Advanced I/O (Record Locking)
