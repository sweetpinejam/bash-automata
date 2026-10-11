# Tactical Field Manual: The Orphan Graveyard (Zombie Reaping & `wait`)

## 1. The Architecture (Why Zombie Processes Exist)
When a Linux process finishes its work and calls `exit(status)`, the kernel frees its memory, closes its open file descriptors, and releases its CPU allocations.
However, **one thing remains in the kernel: its entry in the Process Table**!

The kernel keeps the terminated process in state **`Z` (Zombie / Defunct)** until its parent process reads its exit status code via the `wait()` or `waitpid()` system calls.

```
 [ Parent Process ] ──( forks worker )──▶ [ Child Process ]
        │                                         │
        │                                    ( runs job )
        │                                         │
        │                                    calls exit(0)
        │                                         │
        ▼                                         ▼
 ( DOES NOT CALL wait )                   [ STATE Z: ZOMBIE ]
                                        (Trapped in Process Table)
```

---

## 2. The Danger: PID Table Exhaustion
Every operating system kernel has a finite pool of available Process IDs (`/proc/sys/kernel/pid_max`, typically 32,768).
If a long-running manager or bot constantly spawns background tasks without calling `wait`:
1. The process table fills with thousands of `[defunct]` entries.
2. The operating system runs out of PIDs.
3. Any future command throws:
   `fork: Resource temporarily unavailable`!
4. The server can no longer execute any new processes (including SSH logins!).

---

## 3. The Solution: Actively Reaping Children in Bash

### Method 1: The Collective `wait`
If all background workers must finish before the script proceeds:
```bash
for job in "${jobs[@]}"; do
    run_task "$job" &
done

# Wait for ALL children to finish and reap their zombie entries:
wait
```

### Method 2: Dynamic Throttled Reaping (`wait -n`)
If you are running a pool of 5 workers and want to reap whoever finishes first:
```bash
# In Bash 4.3+, wait -n waits for the NEXT single child to finish:
wait -n
```

---

## 4. How to Spot Zombies in Production
```bash
# Find all zombie processes on the host:
ps -eo pid,ppid,stat,comm | grep -w Z

# Inspect process state in top/htop: look at the 'zombie' count in header
```

---

## 5. Mission Objective
Edit `supervisor.sh` in your sandbox. Ensure all 20 background workers are properly reaped via `wait` so that zero zombie processes accumulate in the Linux process table.
Verify with `[4] Run State Verification`.
