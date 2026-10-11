# Tactical Field Manual: The Orphan Graveyard (Zombie Process Reaping, Process Table Limits & `wait`)

## 1. Systems Mental Model: The Anatomy of a Zombie (`TASK_ZOMBIE`)
When a process finishes its task in Linux, it executes the `exit(2)` system call.
The operating system kernel immediately frees the process's allocated virtual memory pages (`mm_struct`), closes its open file descriptors (`files_struct`), and releases its CPU runqueue priority.

**However, the kernel cannot completely erase the process from existence.**
The process entry must remain in the **Kernel Process Table** in state **`Z` (Zombie / `TASK_ZOMBIE`)**:

```
 [ Parent Process ] ──( fork() / background & )──▶ [ Child Worker ]
        │                                                  │
        │                                             ( runs job )
        │                                                  │
        │                                             calls exit(0)
        │                                                  │
        ▼                                                  ▼
 ( DOES NOT CALL wait )                            [ STATE Z: ZOMBIE ]
                                                - Memory: 0 KB freed
                                                - FDs: All closed
                                                - PID: Still allocated in /proc!
```

### Why the Kernel Retains Zombies:
The kernel keeps the zombie entry alive so that its parent process can eventually read:
1. **The Exit Status Code**: Did the child exit 0, or crash with 1, 127, 137?
2. **Termination Signal**: Was the child killed by `SIGTERM` or `SIGKILL`?
3. **Resource Accounting**: Total CPU user/system time accumulated by the child.

Once the parent calls `wait(2)` or `waitpid(2)`, the kernel delivers the exit record and **permanently purges the PID from the process table** ("reaping the child").

---

## 2. The Catastrophe: System-Wide PID Table Starvation
A zombie process consumes **0 bytes of RAM and 0% CPU**. Because of this, inexperienced engineers assume zombies are harmless.

**They are lethal in production.**
Every operating system kernel maintains a finite ceiling of available Process IDs (`PID` integers):
```bash
cat /proc/sys/kernel/pid_max   # Default on Linux: 32768
```

If an automated batch processor or cron supervisor spawns background worker jobs in a loop without calling `wait`:
1. Terminated workers accumulate as `[defunct]` zombie entries in the process table.
2. The number of active PIDs climbs until hitting `pid_max`.
3. **The Kernel Refuses All Future Forks**:
   Any new attempt to run a command fails with:
   ```
   bash: fork: Resource temporarily unavailable (EAGAIN)
   ```
4. Systems administrators cannot even log in over SSH or run `ps` because spawning an SSH session or running a command requires allocating a new PID!

---

## 3. The Ultimate Myth: "Can I `kill -9` a Zombie?"
**No. You cannot kill a zombie process.**
A zombie process is already dead! Its memory is gone and its threads have terminated. Signals can only be delivered to living processes.

There are only two ways to eliminate a zombie from the Linux kernel:
1. **The Parent Reaps It**: The parent process calls `wait`, reading its exit code.
2. **The Parent Dies**: When the parent process terminates, the Linux kernel automatically reparents all orphaned children to **PID 1 (`/sbin/init` or `systemd`)**. PID 1 is engineered to continuously invoke `wait()`, instantly reaping any adopted zombies.

---

## 4. Reaping Implementations in Bash

### Method 1: The Collective Barrier (`wait`)
When you spawn a batch of background workers and want the supervisor to wait until all workers have finished before proceeding:
```bash
for job in "${batch[@]}"; do
    process_task "$job" &
done

# Blocks until ALL background child subshells have exited, reaping every zombie:
wait
```

### Method 2: Dynamic Worker Pool Reaping (`wait -n`)
In modern Bash (4.3+), if you are maintaining a fixed pool of $N$ workers:
```bash
# Wait for the NEXT single child process to terminate:
wait -n
```
This allows spawning a replacement worker immediately when any slot opens up.

---

## 5. Production Incident Triage: Detecting Zombies

```bash
# List all zombie processes along with their Parent PID (PPID):
ps -eo pid,ppid,stat,comm | grep -w Z
```

| Field | Example | Interpretation |
| :--- | :--- | :--- |
| `PID` | `21045` | The process ID occupied by the zombie. |
| `PPID` | `21020` | **The negligent parent process that failed to call `wait`!** |
| `STAT` | `Z` / `Z+` | Process is in `TASK_ZOMBIE` defunct state. |
| `COMM` | `<worker.sh>` | Command name (often rendered as `<worker.sh> <defunct>`). |

To fix an un-reaped zombie storm in production:
1. Identify the negligent parent process via `PPID`.
2. Inspect why the parent daemon is stuck or not calling `wait`.
3. Restart or terminate the parent process to trigger kernel reparenting to PID 1.

---

## 6. Curated Reading & Reference Guide

* **`man 2 wait` & `man 2 waitpid`**: System call specification detailing process state transitions, `WNOHANG`, and exit status macros (`WIFEXITED`, `WEXITSTATUS`).
* **`man 2 prctl` (Search for `PR_SET_CHILD_SUBREAPER`)**: Linux kernel documentation on how modern supervisors adopt grandchildren instead of letting them reparent to PID 1.
* **`man 5 proc` (Search for `/proc/sys/kernel/pid_max`)**: Kernel parameters governing process table limits and PID recycling.
* **POSIX IEEE Std 1003.1-2017 (Volume System Interfaces)**: Section 2.14 (*Special Built-In Utilities: wait*).
* **Michael Kerrisk: *The Linux Programming Interface (TLPI)***: Chapter 26 (*Monitoring Child Processes*) — The definitive technical guide to zombies, orphans, and SIGCHLD delivery.
* **Brendan Gregg: *Systems Performance: Enterprise and the Cloud***: Chapter 4 (*CPUs and Scheduling*) — Discussion of run queues and process table overhead.

---

## 7. Self-Assessment Checklist
Before modifying `supervisor.sh`:

1. **Why does a terminated process remain in the kernel process table as a zombie?**
   * *Answer*: To preserve its exit status code and CPU resource usage until the parent process reads it via `wait()`.
2. **Why does `kill -9 <zombie_pid>` fail to remove a zombie process?**
   * *Answer*: Because the process is already dead and has no execution context to receive signals; only the parent calling `wait` (or parent termination) frees the table entry.
3. **What critical system error occurs when too many un-reaped zombies accumulate?**
   * *Answer*: System-wide PID exhaustion (`EAGAIN: fork: Resource temporarily unavailable`), which prevents new processes from starting.
4. **How do you identify which parent process is responsible for leaking zombies?**
   * *Answer*: By running `ps -eo pid,ppid,stat,comm | grep -w Z` and inspecting the `PPID` column.
5. **What does calling bare `wait` without arguments do in a Bash script?**
   * *Answer*: It blocks execution until all currently active child background processes terminate, actively reaping each child's process table entry.

---

## 8. Mission Objectives
Refactor `supervisor.sh` into a robust batch supervisor that leaves zero zombie processes in the Linux process table:
1. Enable strict defensive execution (`set -euo pipefail`).
2. Accept CLI options: `--tasks <N>` (default: 20) and `--output <PATH>`.
3. Spawn background worker tasks in parallel to process the batch workload.
4. Actively reap all background child worker processes using `wait`.
5. Ensure all 20 tasks write completion entries to `batch.done`.
6. Ensure zero zombie processes (`[defunct]`) remain in `ps` after execution completes.
7. Output `SUPERVISOR_DONE`.
