# Structural Scaffolding: Child Process Reaping & PCB Deallocation

When a process executes in the background (`&`), its lifecycle transitions to `TASK_ZOMBIE` upon completion. The Linux kernel frees memory pages and file descriptors immediately, but preserves the Process Control Block (PCB) entry containing the PID and exit status until the parent process calls `wait(2)`.

---

## Pattern A: Collective Barrier Reaping

If all tasks are spawned as a parallel batch and the supervisor must block until every single worker has concluded:

```bash
# 1. Dispatch workers into background
for (( i=1; i<=TOTAL_TASKS; i++ )); do
    (
        do_work "$i"
    ) &
done

# 2. Collective Reaping Barrier:
# Blocks until ALL child processes spawned by this shell have terminated,
# releasing their PIDs back to the OS pid_max pool.
wait
```

---

## Pattern B: Dynamic Worker Pool Reaping (`wait -n`)

For fixed-size worker pools where the supervisor must not spawn more than `MAX_CONCURRENT` jobs at once, `wait -n` reaps each worker dynamically as it finishes:

```bash
MAX_CONCURRENT=4
RUNNING=0

for task in "${TASKS[@]}"; do
    run_worker "$task" &
    RUNNING=$(( RUNNING + 1 ))

    if [[ "$RUNNING" -ge "$MAX_CONCURRENT" ]]; then
        # Wait for any single child to exit and reap it
        wait -n
        RUNNING=$(( RUNNING - 1 ))
    fi
done

# Drain remaining workers
wait
```

---

## Verification Check

Inspect your process tree during execution to confirm zero lingering zombies:
```bash
ps -eo pid,ppid,stat,comm | grep -w Z
```
No entries with status `Z` or `<defunct>` should remain after execution completes.
