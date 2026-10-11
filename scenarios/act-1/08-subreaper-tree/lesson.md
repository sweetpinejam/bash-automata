# Tactical Field Manual: The Subreaper Tree (Process Groups & Cascading Teardown)

> **POSIX & Linux Systems Engineering Handbook**  
> **Subsystem**: Linux Process Hierarchy (`task_struct`), Reparenting (`kernel/exit.c`), `PR_SET_CHILD_SUBREAPER`, and Process Group Signaling

---

## 1. Architectural Mental Model: The Grandchild Orphan Problem

In Unix operating systems, processes form a strict hierarchical tree rooted at `PID 1` (`systemd` or `init`). Each process is represented by a `struct task_struct` containing pointers to its parent (`parent`), its children (`children`), and its siblings (`sibling`).

When an orchestration supervisor (A) starts a workload pipeline (B), and that pipeline forks background worker tasks (C₁, C₂, C₃):

```
       [ Orchestrator A (PID 100) ]
                   │
           [ Pipeline B (PID 101) ]
                   │
    ┌──────────────┼──────────────┐
    ▼              ▼              ▼
[ Worker C₁ ]  [ Worker C₂ ]  [ Worker C₃ ]
  (PID 102)      (PID 103)      (PID 104)
```

### What Happens When You `kill $pipeline_pid`?
When the supervisor issues `kill -TERM 101`:
1. The kernel delivers `SIGTERM` exclusively to Process B (PID 101).
2. Process B terminates.
3. In `kernel/exit.c`, the kernel calls `forget_original_parent()`: because the immediate parent of C₁, C₂, and C₃ has died, the kernel **re-parents** the orphan workers to the nearest ancestor reaper (by default, `PID 1`).
4. **Workers C₁, C₂, and C₃ continue executing in the background indefinitely!**

```
                 [ PID 1 (systemd / init) ]
                             │  ▲  ▲
     ┌───────────────────────┘  │  │ (Reparented!)
     ▼                          │  │
[ Worker C₁ ] ────────── [ Worker C₂ ] ────────── [ Worker C₃ ]
(Survives indefinitely, hogging ports, memory, and CPU!)
```

In CI/CD pipelines, container hosts, and batch executors, rogue grandchild processes cause leaked listening sockets, disk write corruption, and silent resource starvation.

---

## 2. Kernel Primitives & Eradication Mechanisms

Linux provides four distinct strategies to eliminate process trees cleanly:

### Strategy 1: Recursive PPID Traversal (`pkill -P $PID`)
The `pkill` command queries `/proc` and matches processes whose Parent PID (`ppid`) matches the target:

```bash
# Terminate all direct children of the target:
pkill -P "$pipeline_pid" 2>/dev/null || true

# Then terminate the target itself:
kill -TERM "$pipeline_pid" 2>/dev/null || true
```

*Trade-off*: `pkill -P` matches only direct children. If workers spawned their own background great-grandchildren, you must recurse through the tree or terminate the process group.

### Strategy 2: POSIX Process Group Signaling (`kill -- -$PGID`)
Every process belongs to a Process Group identified by a `PGID` (`man 2 setpgid`). If a pipeline is configured as a process group leader (e.g. running under job control `set -m` or launched via Python with `preexec_fn=os.setpgrp`):
- Passing a **negative PID** to `kill(2)` tells the Linux kernel to broadcast the signal to **every process in that process group**:

```bash
# Discover PGID of target:
pgid=$(ps -o pgid= -p "$pipeline_pid" | tr -d ' ')

# Broadcast SIGTERM to all processes sharing that PGID:
kill -TERM -- "-$pgid" 2>/dev/null || true
```

### Strategy 3: Linux Subreaper Semantics (`PR_SET_CHILD_SUBREAPER`)
Introduced in Linux kernel 3.4, `prctl(PR_SET_CHILD_SUBREAPER, 1)` marks the calling process as a **subreaper**:
- When any descendant process loses its immediate parent, the kernel does **not** reparent the orphan to `PID 1`.
- Instead, the orphan is reparented to the **nearest ancestor subreaper**!
- The subreaper can then collect orphan exit codes via `waitpid(-1, ...)` and terminate lingering trees. Modern init systems (systemd, Docker containerd) use subreapers to manage container process trees.

### Strategy 4: Control Groups v2 (`cgroup.kill`)
In modern systemd and cgroups v2, assigning a job its own cgroup slice enables atomic tree eradication:
```bash
echo "1" > /sys/fs/cgroup/job_slice/cgroup.kill
```
The kernel atomically freezes and terminates all threads and processes in the cgroup slice with zero fork-racing windows.

---

## 3. Production Gotchas & Hazards

| Hazard | Cause | Prevention / Solution |
| :--- | :--- | :--- |
| **Interactive Terminal Death** | Running `kill -TERM -- -$$` in an interactive bash session kills your terminal emulator and closes your SSH connection! | Only broadcast to `-$PGID` when running inside an isolated child process group or dedicated batch session. |
| **Fork-Racing During Teardown** | A rogue worker forks new children while `pkill -P` is executing. | Send `SIGSTOP` first to freeze the process tree before sending `SIGKILL`, or use cgroup v2 `cgroup.kill`. |
| **PID Recycling Hazard** | An orphan terminates and an unrelated system process claims its reused PID before teardown signals arrive. | Check process start time (`/proc/$PID/stat` field 22) or use pidfds (`pidfd_open(2)` in Linux 5.3+). |

---

## 4. Curated Reading List & Authoritative Manuals

Study these authoritative system documentation sources to master Linux process hierarchies:

1. **`man 2 prctl`**
   - Read the exact specifications for `PR_SET_CHILD_SUBREAPER` and `PR_GET_CHILD_SUBREAPER`.
2. **`man 2 kill`**
   - Detailed specification of negative PID arguments: `pid < -1` signals process group `-pid`.
3. **`man 2 setpgid` & `man 2 setsid`**
   - Process group and session establishment across Unix process trees.
4. **`man 1 pkill`**
   - Review the `-P ppid` parent matching filter and signal dispatch options.
5. **Linux Kernel Source**: `kernel/exit.c`
   - Examine `forget_original_parent()` and `find_new_reaper()` to see how the kernel searches for ancestor subreapers before falling back to `init`.
6. **The Linux Programming Interface (TLPI) by Michael Kerrisk**
   - *Chapter 26: Monitoring Child Processes* — Section 26.2 (Orphans and Re-parenting)
   - *Chapter 34: Process Groups, Sessions, and Job Control* — Section 34.2 (Process Groups)

---

## 5. Self-Assessment Checklist

Test your understanding of Linux process trees:
- [ ] Why does killing a parent process leave grandchild background workers running instead of terminating them?
- [ ] What is the exact function of `forget_original_parent()` in the Linux kernel during process exit?
- [ ] How does `prctl(PR_SET_CHILD_SUBREAPER)` change the reparenting destination of orphan processes?
- [ ] What is the difference between `kill -TERM $PID` and `kill -TERM -- -$PID`?
- [ ] Why is `pkill -P "$target_pid"` followed by `kill -TERM "$target_pid"` necessary when teardown must eradicate both children and parent?
