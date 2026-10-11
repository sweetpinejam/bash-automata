# Tactical Field Manual: The Runaway Worker Pool (`wait -n` & Dynamic Pipelining)

> **POSIX & Linux Systems Engineering Handbook**  
> **Subsystem**: Linux Process Management, `waitpid(2)` / `waitid(2)` System Calls, and Dynamic Concurrency Pipelining

---

## 1. Architectural Mental Model: Lockstep Stalls vs Dynamic Pipelining

In batch execution pipelines (data ingestion, ETL jobs, container image building, test runners), concurrency is bounded to prevent resource exhaustion (e.g. $N=3$ concurrent workers).

A widespread anti-pattern is **Lockstep Batching**:
```bash
# 💥 THE LOCKSTEP BATCHING ANTIPATTERN:
for task in "${tasks[@]}"; do
    run_worker "$task" &
    (( active++ ))
    if (( active >= 3 )); then
        wait      # STALLS! Blocks until ALL 3 workers finish
        active=0
    fi
done
```

### The Straggler Problem (Tail Latency Amplification)
In real-world systems, tasks have variable execution times due to payload size, I/O latency, or network jitter. Consider a 3-worker pool where Task 1 takes 100ms, while Tasks 2 and 3 take only 15ms:

```
Lockstep Batching (Collective 'wait' barrier):
Slot 1: [════════════ Slow Job (100ms) ════════════]
Slot 2: [== Fast (15ms) ==] (IDLE 85ms .............) ──▶ BLOCKED WAITING FOR SLOT 1!
Slot 3: [== Fast (15ms) ==] (IDLE 85ms .............) ──▶ BLOCKED WAITING FOR SLOT 1!
Total Time: 100ms | Idle CPU Waste: ~60%

Dynamic Pipelining ('wait -n' replenishment):
Slot 1: [════════════ Slow Job (100ms) ════════════]
Slot 2: [== Fast ==][== Fast ==][== Fast ==][== Fast ==] ──▶ REFILLED IMMEDIATELY!
Slot 3: [== Fast ==][== Fast ==][== Fast ==][== Fast ==] ──▶ REFILLED IMMEDIATELY!
Total Time: 100ms | 9 Tasks Complete in parallel without idle stalls!
```

Under lockstep batching, overall throughput drops toward the worst-case tail latency of the slowest task in every single batch.

---

## 2. Kernel Primitives & The `wait -n` Syscall Translation

### How Linux Reaps Child Processes
When a child process terminates, the kernel preserves its Process Control Block (PCB) until the parent calls:
- **`waitpid(-1, &status, 0)`**: Reaps *any* single child process that has exited.
- **`waitid(P_ALL, 0, &infop, WEXITED)`**: Linux 2.6+ primitive allowing wait options without polling.

### Bash Evolution: The `wait -n` Primitive
Before Bash 4.3, shell scripts had no built-in way to wait for *any* child process without spinning in a CPU loop or relying on named pipes.
- **Bash 4.3+ (`wait -n`)**: Blocks execution until **any single background job** from the current shell terminates. It reaps that child process and returns its exit code.
- **Bash 5.1+ (`wait -n -p VAR`)**: Reaps any single child and stores its PID in the variable `VAR`, allowing the parent to track exactly which worker finished!

---

## 3. Defensive Shell Hygiene: Arithmetic Traps under `set -e`

In Bash, decrementing a counter using standalone arithmetic commands can trigger a catastrophic abortion when `set -e` is active:

```bash
set -e
active=1
(( active -= 1 ))   # 💥 SCRIPT CRASHES HERE!
```

### Why Does This Crash?
In Bash, `(( expression ))` returns exit status `0` if the expression evaluates to a **non-zero value**, and exit status **`1`** if the expression evaluates to **`0`**!  
When `active` transitions from `1` to `0`, `(( 0 ))` returns exit code 1, which under `set -e` immediately terminates the supervisor!

### The Safe Pattern:
Always use standard variable assignment arithmetic:
```bash
active=$(( active - 1 ))
```
Variable assignment arithmetic never returns a non-zero exit status regardless of the numeric result.

---

## 4. The Complete Dynamic Worker Pool Architecture

```bash
MAX_WORKERS=3
active=0

while IFS= read -r task || [[ -n "$task" ]]; do
    [[ -n "$task" ]] || continue

    # Dispatch worker to background
    run_worker "$task" &
    active=$(( active + 1 ))

    # If capacity reached, wait for ANY single child to finish
    if (( active >= MAX_WORKERS )); then
        wait -n
        active=$(( active - 1 ))
    fi
done < queue.txt

# Final Barrier: Drain remaining active workers (1 or 2 slots still running)
wait
```

---

## 5. Production Gotchas & Edge Cases

| Hazard | Cause | Prevention / Solution |
| :--- | :--- | :--- |
| **Worker Failure Ignored** | `wait -n` returns the exit code of the terminating worker, but if ignored, failed jobs go unnoticed. | Capture exit status: `wait -n \|\| log_error "Worker failed with code $?"`. |
| **Missing Final Barrier** | Loop finishes reading the queue file and exits without a final `wait`. Remaining background workers are killed or orphaned. | Always place an unconditional `wait` after the queue loop to drain the final active workers. |
| **PID Collisions Across Runs** | Fast process churn can cause Linux PID reuse. | In Bash 5.1+, use `wait -n -p finished_pid` to match finished tasks against a recorded active PID associative array. |

---

## 6. Curated Reading List & Authoritative Manuals

Study these authoritative system documentation sources to master Linux worker pools:

1. **`man 2 wait` & `man 2 waitpid`**
   - The Linux Programmer's Manual on child process state changes, zombie harvesting, and `waitpid(-1)` semantics.
2. **`man 2 waitid`**
   - Deep kernel specifications on `P_ALL`, `P_PID`, `P_PGID` process waiting flags.
3. **`man 1 bash`**
   - Search for `wait [-n] [-p varname]` to review Bash reference manual specifications across versions 4.3 and 5.1.
4. **The Linux Programming Interface (TLPI) by Michael Kerrisk**
   - *Chapter 26: Monitoring Child Processes* — Section 26.1 (Waiting on a Child Process: `wait()` and `waitpid()`), Section 26.3 (The `waitid()` System Call).
5. **Brendan Gregg: *Systems Performance: Enterprise and the Cloud***
   - *Chapter 6: CPUs* — Concurrency Bounds, Amdahl's Law, and Worker Pool Sizing.

---

## 7. Self-Assessment Checklist

Test your understanding of dynamic worker pools:
- [ ] Why does lockstep batching (`wait` every $N$ jobs) degrade throughput when tasks have variable execution times?
- [ ] What is the exact difference between `wait` (no arguments) and `wait -n` in Bash?
- [ ] Why does `(( active -= 1 ))` trigger a silent fatal crash when `active` reaches 0 under `set -e`?
- [ ] How does `wait -n` map to underlying Linux system calls (`waitpid` vs `waitid`)?
- [ ] Why is an unconditional `wait` command strictly mandatory after the queue loop completes?
