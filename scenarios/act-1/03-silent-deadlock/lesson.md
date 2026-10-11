# Tactical Field Manual: The Silent Deadlock (Bidirectional FIFO Blocking & Kernel Wait Channels)

## 1. Systems Mental Model: The POSIX FIFO Open Contract
Under the POSIX specification, a Named Pipe (FIFO) special file enforces strict mutual synchronization rules upon the `open(2)` system call:
* Opening a FIFO for read-only access (`open(path, O_RDONLY)`) **blocks unconditionally** until another process opens the exact same FIFO for writing (`O_WRONLY`).
* Opening a FIFO for write-only access (`open(path, O_WRONLY)`) **blocks unconditionally** until another process opens the exact same FIFO for reading (`O_RDONLY`).

```
    Process 1 (agent.sh)               Kernel VFS Inodes               Process 2 (controller.py)
 ─────────────────────────         ─────────────────────────         ─────────────────────────────
  open(resp.fifo, READ)   ──(blocks)─▶    [ resp.fifo ]    ◀──(waiting)──   open(resp.fifo, WRITE)
            │                                                                         ▲
            ▼                                                                         │
     (NEVER REACHED)                                                           (NEVER REACHED)
  open(req.fifo, WRITE)   ──(waiting)─▶   [ req.fifo ]     ◀──(blocks)───   open(req.fifo, READ)
```

### The Anatomy of the Silent Freeze:
When two cooperating processes communicate over two distinct FIFOs (one for requests, one for responses):
1. **Process 1 (Agent)** executes `cat resp.fifo > handshake.log`. The kernel enters `fifo_open()` and suspends Process 1, waiting for a writer to open `resp.fifo`.
2. **Process 2 (Controller)** executes `open("req.fifo", "r")`. The kernel enters `fifo_open()` and suspends Process 2, waiting for a writer to open `req.fifo`.
3. **The Circular Wait (Coffman Condition #4)**:
   - Process 1 cannot write to `req.fifo` until its read on `resp.fifo` returns.
   - Process 2 cannot write to `resp.fifo` until its read on `req.fifo` returns.
4. **The Result**: Both processes enter an **uninterruptible sleep state (`S` / `D`)**. The operating system will never wake them up; the pipeline is deadlocked forever with 0% CPU utilization.

---

## 2. Syntax & Architectural Solutions: Breaking the Deadlock

To resolve circular FIFO blocking, you must break the synchronous ordering dependency:

### Architectural Pattern 1: Asynchronous Background Writer (POSIX Standard)
Decouple the write operation by spawning it in a background subshell (`&`):
```bash
# 1. Fire the request in the background:
( echo "PING" > req.fifo ) &

# 2. Block on the response:
cat resp.fifo > handshake.log
```
* Spawning `echo "PING" > req.fifo &` immediately invokes `open(O_WRONLY)` in a background subshell.
* The controller's `open(req.fifo, O_RDONLY)` immediately unblocks!
* The controller reads `PING`, opens `resp.fifo` for writing, and unblocks the agent's `cat resp.fifo`.

### Architectural Pattern 2: Bidirectional Descriptor Allocation (`exec 3<>`)
On Linux, opening a pipe in read-write mode (`O_RDWR` via `<>`) opens both read and write ends simultaneously:
```bash
exec 3<> req.fifo
echo "PING" >&3
```
Because the calling process opens both endpoints, `open(2)` returns immediately without blocking.

---

## 3. The Deadly Subshell Trap Inheritance Gotcha
A subtle and notorious trap in Bash asynchronous programming:
In Bash, **background subshells inherit `EXIT` traps from the parent shell**.
If your parent script registers:
```bash
trap 'rm -f req.fifo resp.fifo' EXIT
```
When you launch `( echo "PING" > req.fifo ) &`, that child subshell **runs the `EXIT` trap when it terminates**, immediately unlinking `req.fifo` and `resp.fifo` before the parent or the controller can use them!

### The Defensive Fix: Guard Traps with `$BASHPID`:
```bash
MAIN_PID=$$
trap 'if [[ "$BASHPID" == "$MAIN_PID" ]]; then rm -f req.fifo resp.fifo; fi' EXIT INT TERM
```
* `$$` holds the root script PID.
* `$BASHPID` holds the current subshell's true process ID.
* When a child subshell exits, `$BASHPID != $MAIN_PID`, so the cleanup action is safely skipped!

---

## 4. Production Incident Triage: Diagnosing Deadlocks with `wchan`
When microservice scripts hang indefinitely in CI/CD or production, do not guess. Inspect the kernel wait channel:

```bash
# Inspect process state and kernel wait channel:
ps -o pid,stat,wchan:20,cmd -p $PID
```

| `STAT` Flag | `WCHAN` Output | Diagnostic Interpretation |
| :--- | :--- | :--- |
| `S` (Interruptible Sleep) | `fifo_open` | **Process is frozen waiting for a peer to open the other end of a FIFO.** |
| `S` | `pipe_wait` | Process is waiting for data to arrive on an already-open pipe. |
| `D` (Uninterruptible Sleep) | `sync_page` / `io_schedule` | Process is waiting for disk controller hardware I/O. |

You can also identify the exact locked FIFO using `lsof`:
```bash
lsof -p $PID
```
Look for file descriptors where `TYPE` is `FIFO` and `NAME` points to the stalled pipe.

---

## 5. Curated Reading & Reference Guide

* **`man 7 fifo`**: Foundational manual on POSIX FIFO special files, open blocking semantics, and `PIPE_BUF` atomicity.
* **`man 2 open`**: Review the `O_NONBLOCK` and `O_RDWR` flags on FIFO special files.
* **W. Richard Stevens & Stephen A. Rago: *Advanced Programming in the UNIX Environment (APUE)***: Chapter 15 (*Interprocess Communication*) — Detailed breakdown of client-server FIFO architectures.
* **Linux Kernel Source (`fs/pipe.c`)**: Inspect the `fifo_open()` kernel routine to understand the wait queue mechanism.
* **Coffman, Elphick, and Shoshani (1971): *System Deadlocks***: Foundational computer science paper defining the 4 Coffman conditions (Mutual Exclusion, Hold and Wait, No Preemption, Circular Wait).
* **Bash Reference Manual (Section on `BASHPID` vs `$$`)**: Why `$BASHPID` differs in subshells and how subshell traps are isolated.
* **`man 1 ps`**: Review the `-o wchan` format specifier for viewing the kernel function where a sleeping process is blocked.

---

## 6. Self-Assessment Checklist
Before modifying `agent.sh`:

1. **Why does `open("pipe", O_RDONLY)` block when no writer exists?**
   * *Answer*: POSIX specifies that reading from a FIFO requires a peer writer; the kernel suspends the calling thread until a writer attaches.
2. **Which of the 4 Coffman deadlock conditions is triggered when two processes wait to read each other's FIFOs?**
   * *Answer*: Condition 4: Circular Wait (Process A waits on Process B, while Process B waits on Process A).
3. **What kernel wait channel (`wchan`) appears in `ps` when a process is blocked opening a FIFO?**
   * *Answer*: `fifo_open` (or `pipe_wait`).
4. **Why do background subshells prematurely delete FIFOs if `trap 'rm -f ...' EXIT` is unguarded?**
   * *Answer*: Subshells inherit the `EXIT` trap; when the background subshell exits, it executes the trap and unlinks the FIFOs before the parent finishes.
5. **How does comparing `$BASHPID` to `$$` protect against subshell trap execution?**
   * *Answer*: `$BASHPID` reflects the current subshell's true PID, while `$$` remains the parent script's PID, allowing the trap handler to skip cleanup when running inside child subshells.

---

## 7. Mission Objectives
Refactor `agent.sh` into a fault-tolerant IPC agent that performs a clean bidirectional ping-pong handshake:
1. Enable strict defensive execution (`set -euo pipefail`).
2. Implement CLI options: `--req-fifo <PATH>`, `--resp-fifo <PATH>`, `--log-file <PATH>`.
3. Register a PID-guarded cleanup trap (`[[ "$BASHPID" == "$MAIN_PID" ]]`) to ensure both FIFOs are unlinked upon exit.
4. Launch the background supervisory controller (`python3 controller.py &`).
5. Decouple the handshake: dispatch `PING` into `req.fifo` without blocking the parent shell.
6. Drain the supervisory acknowledgement from `resp.fifo` into `handshake.log`.
7. Await controller completion cleanly and output `HANDSHAKE_COMPLETE` within 2.0 seconds.
