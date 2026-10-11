# Tactical Field Manual: The Leaking Descriptor (Custom FDs & `/proc/$$/fd`)

## 1. The Architecture (The Linux File Descriptor Table)
In the Linux kernel, every process possesses an array of pointers called the **File Descriptor Table**:
* `0`: `stdin` (Standard Input)
* `1`: `stdout` (Standard Output)
* `2`: `stderr` (Standard Error)

When writing advanced shell systems, hardcoding descriptors 0, 1, and 2 is limiting. 
Bash allows creating **custom file descriptors** (3 through 9, or dynamically allocated using `{var}`):

```bash
# Static allocation:
exec 3< "/path/to/file"

# Modern dynamic allocation (Bash 4.1+):
exec {fd}< "/path/to/file"
echo "Allocated descriptor: $fd"  # e.g., 10, 11, 12...
```

---

## 2. The Danger: Operating System Descriptor Exhaustion
The operating system imposes limits on the number of open file descriptors per process (`ulimit -n`, typically 1024) and system-wide (`/proc/sys/fs/file-max`).

If a daemon opens descriptors in a loop without closing them:
```bash
for file in logs/*; do
    exec {fd}< "$file"   # 💥 Leaks 1 descriptor per iteration!
    # Missing closure!
done
```
Once the limit is reached, **all future system calls (`open()`, `socket()`, `pipe()`, `fork()`) fail** with:
`Too many open files`.
This will crash not only your script, but any neighboring services on the machine.

---

## 3. How to Close File Descriptors in Bash

To close a descriptor, redirect it to **`&-`** using `exec`:

| Allocation | Syntax to Open | Syntax to Close |
| :--- | :--- | :--- |
| **Input FD** | `exec {fd}< "$file"` | `exec {fd}<&-` |
| **Output FD** | `exec {fd}> "$file"` | `exec {fd}>&-` |
| **Static FD 3** | `exec 3< "$file"` | `exec 3<&-` |

---

## 4. How to Inspect Descriptors in Production
In Linux, you can inspect the open descriptors of any running process in real-time:
```bash
ls -l "/proc/$$/fd"
```
Or with `lsof`:
```bash
lsof -p $$
```

---

## 5. Mission Objective
Edit `monitor.sh` in your sandbox. Add `exec {fd}<&-` after reading from the status file so that the daemon completes 50 polling cycles under a strict `ulimit -n 25` limit without crashing.
