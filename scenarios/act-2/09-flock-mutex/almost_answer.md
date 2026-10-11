# Structural Scaffolding: Scenario 2.09 (The Advisory Lock Contest)

> **Objective**: Synchronize multi-process concurrent writes to a shared file using Linux kernel advisory file locks (`flock`) on a dedicated file descriptor.

---

### Architectural Pattern: Kernel Advisory Mutex

When multiple worker processes write multi-line records to a shared file, relying on shell append (`>>`) fails because the kernel schedules each `write(2)` syscall independently. 

To guarantee atomicity across multiple write syscalls:
1. Open a dedicated lock file descriptor (e.g. `200`) pointing to a lockfile.
2. Guard the multi-line record write inside a critical section bounded by `flock -x 200` (exclusive lock acquisition) and `flock -u 200` (release).
3. Close the file descriptor when finished.

```
Worker A                              Kernel Inode Lock Table               Worker B
   │                                             │                             │
   ├─► exec 200>"metrics.lock"                   │                             │
   ├─► flock -x 200 ────────────────────────────►│ [LOCK GRANTED to A]         │
   │   (In Critical Section)                     │                             │
   │   echo "START_ROW"                          │                             ├─► exec 200>"metrics.lock"
   │   echo "payload..."                         │                             ├─► flock -x 200 (BLOCKED)
   │   echo "END_ROW"                            │                             │        ┆
   ├─► flock -u 200 ────────────────────────────►│ [LOCK RELEASED]             │        ┆
   │                                             │                             │        ▼
   │                                             ├────────────────────────────►│ [LOCK GRANTED to B]
   │                                             │                             │   (In Critical Section)
```

---

### Structural Skeleton

```bash
# 1. Configuration & Lock File
LOCK_FILE="metrics.lock"
OUTPUT_FILE="metrics_dump.tsv"

# 2. Open dedicated high-numbered file descriptor for the lock
exec 200>"$LOCK_FILE"
trap 'exec 200>&- 2>/dev/null || true' EXIT INT TERM

# 3. Iteration Loop with Guarded Critical Section
for (( i=1; i<=RECORDS_COUNT; i++ )); do
    # Acquire exclusive kernel advisory lock on FD 200
    # (Blocks until any current lock holder releases)
    flock -x 200

    # CRITICAL SECTION: All writes in this block remain contiguous
    echo "START_ROW" >> "$OUTPUT_FILE"
    sleep 0.005
    echo -e "worker=$WORKER_ID\tseq=$i\tdata=payload_$i" >> "$OUTPUT_FILE"
    echo "END_ROW" >> "$OUTPUT_FILE"

    # Release exclusive lock so other workers can proceed
    flock -u 200
done

# 4. Cleanly close file descriptor
exec 200>&-
```

---

### Key Operational Rules

1. **Dedicated Lock File vs Data File**:
   Never run `flock` directly on the data file if it is opened in truncate (`>`) or append (`>>`) modes inside the loop. Using an independent `.lock` file avoids file descriptor collisions and file corruption.

2. **File Descriptor Numbering Convention**:
   Use file descriptors numbered `>= 3` (commonly `200` or `201`) to avoid conflicting with standard streams (`0` stdin, `1` stdout, `2` stderr) and standard shell pipelines.

3. **Kernel Automatic Cleanup on Termination**:
   If a worker crashes or is killed by a signal (`SIGTERM` or `SIGKILL`), the Linux kernel automatically closes all open file descriptors for that process and releases any held `flock` locks, preventing permanent deadlocks.
