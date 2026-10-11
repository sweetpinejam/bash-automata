# Tactical Field Manual: The Lockfile Mutex & Stale Lock Recovery

## 1. Systems Mental Model: The TOCTOU Flaw in Filesystem Mutual Exclusion
When scheduled cron jobs, event workers, or deployment scripts run periodically, preventing concurrent overlapping runs is essential to protect databases and shared state.

In naive shell scripts, developers frequently write:
```bash
# 💥 THE TOCTOU DISASTER (Time-of-Check to Time-of-Use):
if [[ ! -f "sync.lock" ]]; then
    # <--- VULNERABILITY GAP! Operating system switches context here!
    touch "sync.lock"
    run_critical_sync
    rm "sync.lock"
fi
```

### Why File Testing Fails:
In POSIX operating systems, checking file existence (`[ ! -f ... ]`) and creating the file (`touch ...`) are **two separate, non-atomic system calls**:
1. Process A checks `sync.lock` -> Does not exist.
2. The Linux kernel scheduler preempts Process A and gives CPU cycles to Process B.
3. Process B checks `sync.lock` -> Does not exist.
4. Process B executes `touch sync.lock` and begins modifying the database.
5. Process A resumes and executes `touch sync.lock`, also modifying the database.
Both processes run simultaneously, causing race conditions, split-brain writes, and corrupted data.

---

## 2. Kernel Primitive: Atomic `mkdir`
Under the POSIX VFS specification, directory creation (`mkdir(2)`) is **strictly atomic** at the kernel and filesystem inode level.
* If the target directory does not exist, the kernel creates it in a single indivisible operation and returns exit code `0`.
* If the target directory already exists, the kernel immediately fails with error code `EEXIST` and returns exit code `1`.

No two processes on the system can simultaneously succeed in creating the same directory:
```bash
if mkdir "$LOCK_DIR" 2>/dev/null; then
    # Lock acquired exclusively
    ...
else
    # Lock already held by another process
    ...
fi
```

> [!CAUTION]
> **Never use `mkdir -p` for mutual exclusion!**
> The `-p` flag instructs the kernel to ignore `EEXIST` errors, succeeding even if the directory already exists. This completely defeats mutex locking!

---

## 3. The Stale Lock Crisis & PID Liveness Attribution
What happens if a process holding `sync.lock` gets killed abruptly by the Linux kernel OOM killer (`SIGKILL`), a hardware power cut, or a crash?
Since `SIGKILL` cannot be trapped, the lock directory remains on disk forever.
If your lock script only checks `mkdir`, all future cron runs will permanently abort, deadlocking the system indefinitely.

To prevent permanent deadlocks, implement **PID Attribution & Liveness Auditing**:

### Step 1: Store PID Inside the Lock Directory
Immediately upon creating the directory, write the script's PID (`$$`) into `$LOCK_DIR/pid`:
```bash
mkdir "$LOCK_DIR" 2>/dev/null && echo "$$" > "$LOCK_DIR/pid"
```

### Step 2: Test Lock Owner Liveness via `kill -0`
When `mkdir` fails, read the PID recorded in `$LOCK_DIR/pid` and test if that process is still running:
```bash
if [[ -f "$LOCK_DIR/pid" ]]; then
    owner_pid="$(cat "$LOCK_DIR/pid")"
    if kill -0 "$owner_pid" 2>/dev/null; then
        # The owner process is genuinely alive in /proc
        echo "LOCK_ACQUIRE_FAILED: Active PID $owner_pid holds lock." >&2
        exit 1
    fi
    # If kill -0 returned non-zero, the process is DEAD!
    echo "[WARN] Stale lock detected (dead PID $owner_pid). Reclaiming..." >&2
    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR" && echo "$$" > "$LOCK_DIR/pid"
fi
```

> [!NOTE]
> `kill -0 <PID>` does **not** send a termination signal to the target process. It only asks the kernel if the calling process has permission to signal that PID. If the process does not exist, the kernel returns exit status `1` (ESRCH: No such process).

---

## 4. Architectural Diagram: Atomic Mutex & Stale Lock Recovery

```
                   [ Worker Starts ]
                           │
                           ▼
                 [ Attempt mkdir $LOCK_DIR ]
                           │
              ┌────────────┴────────────┐
         [ Success (0) ]           [ Failure (1) ]
              │                         │
              ▼                         ▼
      [ Write $$ to $LOCK_DIR/pid ]  [ Read owner PID from $LOCK_DIR/pid ]
              │                         │
              ▼                         ▼
      [ trap release_lock EXIT ]    [ kill -0 $owner_pid ]
              │                         │
              ▼                    ┌────┴─────────────────┐
       [ Execute Task ]     [ Alive (0) ]          [ Dead (!= 0) ]
              │                    │                      │
              ▼                    ▼                      ▼
       [ Auto Unlock ]      [ LOCK_ACQUIRE_FAILED ]  [ Log Stale Lock Warning ]
       (rm -rf $LOCK_DIR)   [ Exit 1 ]               [ rm -rf $LOCK_DIR ]
                                                          │
                                                          ▼
                                                     [ Reclaim: mkdir $LOCK_DIR ]
```

---

## 5. Self-Assessment Checklist
Before modifying `worker.sh`:

1. **Why is `[ ! -f lock ] && touch lock` vulnerable to race conditions?**
   * *Answer*: Because file existence checking and file creation are separate non-atomic system calls, allowing another process to execute between them (TOCTOU).
2. **Why is `mkdir` an atomic synchronization primitive in Linux?**
   * *Answer*: The `mkdir` system call performs directory lookup and inode creation atomically in the VFS layer, failing immediately with `EEXIST` if the path already exists.
3. **Why must `mkdir -p` never be used for locking?**
   * *Answer*: Because `mkdir -p` suppresses errors when the target directory already exists, allowing concurrent executions.
4. **What does `kill -0 "$pid"` do?**
   * *Answer*: It performs error-checking and permission validation on the given PID without sending an actual signal, returning `0` if alive and `1` if the process does not exist.
5. **How does an exit trap protect against abandoned lock directories?**
   * *Answer*: By registering `trap release_lock EXIT INT TERM`, the lock directory is automatically unlinked whenever the process terminates, whether cleanly or due to `set -e` failure.

---

## 6. Mission Objectives
Implement `worker.sh` as an atomic production mutex worker:
1. Enable `set -euo pipefail`.
2. Implement `acquire_lock()`:
   - Try atomic `mkdir "$LOCK_DIR"`.
   - On success: write `$$` into `$LOCK_DIR/pid`.
   - On collision: check if `$LOCK_DIR/pid` exists and whether the owner PID is alive via `kill -0 "$owner_pid"`.
   - If alive: emit `LOCK_ACQUIRE_FAILED` and exit with status 1.
   - If dead (stale lock): log warning, remove stale `$LOCK_DIR`, and reclaim the lock.
3. Implement `release_lock()` registered on `EXIT INT TERM`:
   - Only remove `$LOCK_DIR` if the current process `$$` is the recorded lock owner.
4. Process incoming events from `./events.jsonl`:
   - Aggregate event count and sum of `amount` attributes into `./sync_summary.json`.
5. Support `--hold` (sleep 3s to allow collision testing).
6. Emit final summary log: `MUTEX_WORKER: pid=<PID>, events_processed=<N>, status=SUCCESS`.
