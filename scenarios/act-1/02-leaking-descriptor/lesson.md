# Tactical Field Manual: The Leaking Descriptor (Custom FDs, Table Limits & `/proc/$$/fd`)

## 1. Systems Mental Model: The Linux Kernel File Descriptor Table
Inside the Linux kernel, every process is represented by a `task_struct`. Within this structure lies a pointer to `files_struct`, which contains the **File Descriptor Table**—an array of pointers to open file objects (`struct file`):

```
┌────────────────────────────────────────────────────────┐
│                   PROCESS DESCRIPTOR TABLE             │
│                                                        │
│   FD 0  ──▶ /dev/pts/1          (Standard Input)       │
│   FD 1  ──▶ /dev/pts/1          (Standard Output)      │
│   FD 2  ──▶ /dev/pts/1          (Standard Error)       │
│   FD 3  ──▶ /var/log/sys.log    (Custom Descriptor)    │
│   FD 10 ──▶ /tmp/node.status    (Dynamic Bash {fd})    │
│   FD 11 ──▶ /tmp/node.status    (Leaked from cycle 2)  │
│   FD 12 ──▶ /tmp/node.status    (Leaked from cycle 3)  │
└────────────────────────────────────────────────────────┘
```

### The Invariable Allocation Law:
Whenever a process executes an `open(2)` system call, the Linux kernel is mandated by POSIX to allocate the **lowest numbered unused file descriptor integer**.
* When Bash allocates descriptors dynamically using `{fd}< "file"`, it searches for the lowest unused integer **greater than or equal to 10** (descriptors 0–9 are traditionally reserved for manual redirects).

---

## 2. The Failure Mode: Kernel Exhaustion (`EMFILE`)
The operating system imposes a hard safety ceiling on the maximum number of open file descriptors:
* Per-process limit (`RLIMIT_NOFILE`): configured via `ulimit -n` (typically 1024).
* Host system-wide limit: `/proc/sys/fs/file-max`.

When an unattended automation daemon opens descriptors in a loop without releasing them:
1. Each iteration allocates a new slot in the process descriptor table (`10, 11, 12, ...`).
2. Once the table fills to the `ulimit -n` limit (e.g., 25 or 1024), any subsequent syscall that requests an FD fails immediately with kernel error code **`EMFILE: Too many open files`**.
3. **Catastrophic Failure Scope**: It is not just `open()` that fails. In Linux, **`socket()` (network connections), `pipe()` (inter-process communication), and `accept()` (incoming web requests) all require allocating a file descriptor**. Once the descriptor table is exhausted, the daemon cannot even log an alert or open a socket.

---

## 3. Syntax & Redirection Anatomy: Managing the Lifecycle

To prevent descriptor leakage, every opened file descriptor must be explicitly unlinked from the process table using redirection closure syntax:

| Operation | Static Descriptor (e.g. FD 3) | Dynamic Descriptor (`{fd}`) |
| :--- | :--- | :--- |
| **Open for Reading** | `exec 3< "$file"` | `exec {fd}< "$file"` |
| **Open for Writing** | `exec 3> "$file"` | `exec {fd}> "$file"` |
| **Open for Append** | `exec 3>> "$file"` | `exec {fd}>> "$file"` |
| **Read from FD** | `read -r line <&3` | `read -r line <&"$fd"` |
| **Write to FD** | `echo "data" >&3` | `echo "data" >&"$fd"` |
| **Close Read FD** | `exec 3<&-` | `exec {fd}<&-` |
| **Close Write FD** | `exec 3>&-` | `exec {fd}>&-` |

> [!IMPORTANT]
> Notice the closure syntax: `<&-` (or `>&-`). The minus sign (`-`) instructs the shell to invoke the `close(2)` system call on that descriptor index, recycling the slot in the process table immediately.

---

## 4. Architectural Diagram: Safe Descriptor Lifecycle

```
[ Iteration Begins ]
         │
         ▼
[ Open FD: exec {fd}< "$file" ] ──▶ Kernel allocates lowest unused slot >= 10
         │
         ▼
[ Read Line: read -r line <&"$fd" ]
         │
         ▼
[ Process / Emit Telemetry ]
         │
         ▼
[ Close FD: exec {fd}<&- ] ──────▶ Kernel executes close(fd), frees table slot
         │
         ▼
[ Next Iteration: Ready with Zero Table Accumulation ]
```

---

## 5. Real-World Gotchas & Production Pitfalls

1. **Subshell FD Inheritance**:
   By default, child subshells and background processes (`&`) inherit all currently open file descriptors from the parent shell. If a parent leaks descriptors, all child processes hold open references to those inodes, preventing files from being deleted or unmounted.
2. **Closing in the Right Direction**:
   While `exec {fd}<&-` closes a read descriptor and `exec {fd}>&-` closes a write descriptor, closing either one will invoke the underlying `close(2)` syscall. However, matching the redirection direction (`<` with `<&-`, `>` with `>&-`) maintains POSIX portability across different shell implementations.
3. **Live Kernel Auditing via `/proc`**:
   You can inspect every open file descriptor of any running process in Linux by listing its `/proc` directory:
   ```bash
   ls -l "/proc/$PID/fd"
   ```
   Each entry is a symbolic link pointing to the underlying inode (regular file, socket, pipe, or anonymous inode).

---

## 6. Curated Reading & Reference Guide

* **`man 2 open`**: System call specification detailing file table allocation, `O_RDONLY`, `O_CLOEXEC`, and the `EMFILE` error condition.
* **`man 2 close`**: The POSIX specification for releasing file descriptors and recycling descriptor table integers.
* **`man 2 dup` & `man 2 dup2`**: How descriptors are duplicated across slots in the kernel process table.
* **`man 5 proc` (Search for `/proc/[pid]/fd`)**: Complete kernel documentation on how Linux exposes process file descriptors and descriptor flags (`/proc/[pid]/fdinfo`).
* **POSIX IEEE Std 1003.1-2017 (Volume Shell & Utilities)**: Section 2.7 (*Redirection*) — Subsections 2.7.5 (*Duplicating an Input File Descriptor*) and 2.7.6 (*Duplicating an Output File Descriptor*).
* **Michael Kerrisk: *The Linux Programming Interface (TLPI)***: Chapter 4 (*File I/O: The Universal I/O Model*) and Chapter 5 (*File I/O: Further Details*) — Essential reading for descriptor inheritance and table limits.
* **`man 1 lsof`**: The system administrator's reference for auditing open files, network sockets, and leaking descriptors across running daemon processes.

---

## 7. Self-Assessment Checklist
Before modifying your scripts:

1. **What is the default descriptor table index allocated when using `exec {fd}< file`?**
   * *Answer*: Bash searches for and assigns the lowest available integer greater than or equal to 10.
2. **What kernel error is triggered when a process exceeds its `ulimit -n` limit?**
   * *Answer*: `EMFILE: Too many open files`.
3. **Why does closing descriptors with `<&-` recycle the table slot?**
   * *Answer*: It invokes the `close(2)` system call, which decrements the file object reference count and marks the table slot as available for subsequent `open(2)` calls.
4. **How can you verify from the command line how many descriptors a running shell currently has open?**
   * *Answer*: By inspecting `ls -l /proc/$$/fd | wc -l`.
5. **Why is leaking file descriptors hazardous to network communication?**
   * *Answer*: Because network sockets require file descriptor allocation; once the table is exhausted, `socket()` and `accept()` fail immediately.

---

## 8. Mission Objectives
Refactor `monitor.sh` into a robust health polling daemon:
1. Enable strict defensive execution (`set -euo pipefail`).
2. Implement CLI argument parsing for `--cycles` (default: 50).
3. Safely open the status file using dynamic file descriptor allocation: `exec {fd}< "$status_file"`.
4. Read the incoming telemetry metric line: `read -r line <&"$fd"`.
5. Explicitly close the file descriptor on every cycle before the next iteration: `exec {fd}<&-`.
6. Ensure the daemon runs cleanly through all 50 cycles under a strict `ulimit -n 25` limit with zero descriptor leaks.
7. Record formatted health entries into `monitor.summary` and output `MONITOR_RUN_COMPLETE`.
