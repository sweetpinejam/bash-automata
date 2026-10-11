# Tactical Field Manual: The Kernel Cgroup Throttle (O(1) Streaming vs OOM Kills)

> **POSIX & Linux Systems Engineering Handbook**  
> **Subsystem**: Linux Control Groups v2 (`cgroups-v2`), Memory Resource Controller (`memory.max`), and the Kernel Out-Of-Memory (OOM) Killer

---

## 1. Architectural Mental Model: Linux Control Groups & The OOM Killer

In modern production environments (Docker containers, Kubernetes pods, systemd slices), processes execute inside isolated resource sandboxes managed by Linux **Control Groups (cgroups v2)**.

The cgroup memory controller (`memory.*`) enforces strict physical limits on processes belonging to that group:
- **`memory.current`**: The live total memory consumed by the cgroup (anonymous memory, heap, stack, page cache).
- **`memory.high`**: A throttling boundary; when exceeded, the kernel slows down allocations and aggressively invokes page reclaim.
- **`memory.max`**: The hard, non-negotiable memory ceiling (e.g. 32 MB).

```
   Physical Memory Pressure
             │
   Exceeds memory.max (32 MB)
             │
             ▼
   Kernel page reclaim fails
             │
             ▼
   Kernel invokes OOM Killer ──▶ Delivers uncatchable SIGKILL (Signal 9)
                                    │
                                    ▼
                             Process Slaughtered
                    (No exit traps run, no buffers saved!)
```

### The Uncatchable Death: Signal 9
Unlike `SIGTERM` or `SIGHUP`, **`SIGKILL` cannot be caught, ignored, or handled by a process.**  
When the OOM killer selects a process based on its badness score (`/proc/$PID/oom_score`), the kernel terminates the process immediately inside the scheduler. File descriptor buffers in user-space stdio are lost, lock files remain stale on disk, and batch jobs fail catastrophically.

---

## 2. Shell Internals: The Memory Cost of Bash Arrays

Engineers coming from languages with contiguous array layouts (C, Go, Rust) often assume Bash arrays are lightweight vectors. In reality, GNU Bash is an interpreted environment:

- Every element in a Bash indexed array is represented by a separate heap allocation (`struct ARRAY_ELEMENT`).
- Each struct contains metadata: element index (`int`), string pointer (`char*`), and next/prev pointers for a linked list.
- Appending tens of thousands of lines (`records+=("$line")`):
  1. Issues thousands of small `malloc(3)` allocations, fragmenting the glibc heap.
  2. Retains every single line in heap memory simultaneously ($O(N)$ space complexity).
  3. Inflates Bash process RSS (Resident Set Size) from 3 MB to 40+ MB, immediately breaching container cgroup ceilings.

---

## 3. The Unix Streaming Model ($O(1)$ Constant Space Complexity)

The foundational design philosophy of Unix is the **stream interface**: data should flow continuously through filters rather than being buffered entirely in memory.

```
Input File (feed.raw) ──▶ [ 1 Line in Memory ] ──▶ Output File (processed.log)
                                │
                          Peak RSS: ~3 MB
                      (O(1) Constant Space!)
```

### The Constant Memory Pattern:
```bash
while IFS= read -r line; do
    echo "PROCESSED: $line"
done < "$INPUT_FILE" > "$OUTPUT_FILE"
```

### Why Loop Redirection is Critical:
Notice the syntax:
1. `< "$INPUT_FILE"` redirects standard input for the **entire loop**.
2. `> "$OUTPUT_FILE"` opens the output file **once** at loop initiation and keeps the file descriptor open until the loop terminates.
3. Contrast this with appending inside the loop (`echo ... >> file`): appending inside the loop executes 5,000 `open(O_APPEND)` and `close()` system calls, causing severe storage I/O degradation!

---

## 4. Production Gotchas & Cgroup Accounting

| Hazard | Cause | Prevention / Solution |
| :--- | :--- | :--- |
| **Page Cache Inflation** | Writing large files fills the kernel page cache, which counts toward `memory.current`. | Linux cgroups drop clean page cache pages before triggering OOM; however, high dirty-page ratios can cause stalls. Call `posix_fadvise(POSIX_FADV_DONTNEED)` or sync periodically. |
| **Subshell Variable Loss** | Writing `cat file \| while read -r line; do count=$((count+1)); done` runs the loop in a subshell, losing `count` upon loop exit. | Always redirect input directly into `done < file` so the loop executes in the main shell environment. |
| **Trailing Line Drop** | If the input file lacks a trailing newline (`\n`), standard `while read -r line` terminates before processing the final line. | Use `while IFS= read -r line || [[ -n "$line" ]]; do ... done`. |

---

## 5. Curated Reading List & Authoritative Manuals

Study these authoritative system documentation sources to master Linux cgroups and memory constraints:

1. **`man 7 cgroups`**
   - Overview of Linux control groups, hierarchy rules, and resource isolation controllers.
2. **Linux Kernel Documentation: `Documentation/admin-guide/cgroup-v2.rst`**
   - Read Section 5.2 (Memory) on `memory.current`, `memory.high`, `memory.max`, and `memory.events`.
3. **`man 5 proc`**
   - Search for `/proc/[pid]/status` (`VmRSS`, `VmHWM`), `/proc/[pid]/oom_score`, and `/proc/[pid]/oom_score_adj`.
4. **`man 2 sigaction`**
   - Specifications on signals that cannot be caught or blocked (`SIGKILL` and `SIGSTOP`).
5. **Brendan Gregg: *Systems Performance: Enterprise and the Cloud***
   - *Chapter 7: Memory* — Virtual memory layout, Resident Set Size (RSS), heap fragmentation.
   - *Chapter 11: Control Groups* — Resource controllers, container limits, and OOM killer mechanics.
6. **The Linux Programming Interface (TLPI) by Michael Kerrisk**
   - *Chapter 13: File I/O Buffering* — Section 13.1 (Kernel Buffering: The Buffer Cache)
   - *Chapter 21: Signals: Signal Handlers* — Section 21.1 (Signal Types and Default Actions: `SIGKILL`)

---

## 6. Self-Assessment Checklist

Test your understanding of Linux cgroup memory constraints:
- [ ] What is the difference between `memory.high` and `memory.max` in cgroups v2?
- [ ] Why cannot a script register a `trap ... EXIT` handler to save its state when terminated by the OOM killer?
- [ ] What is the memory complexity ($O$) of buffering lines into a Bash array vs streaming lines via `while read`?
- [ ] Why does `echo ... >> output.log` inside a 5,000-iteration loop perform significantly worse than redirecting the entire loop with `done > output.log`?
- [ ] How does `cat feed.raw | while read -r line` introduce subtle subshell variable scoping bugs compared to `while read -r line; do ... done < feed.raw`?
