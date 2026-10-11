# Tactical Field Manual: The Token Bucket Semaphore (POSIX FIFOs & Bounded Concurrency)

> **POSIX & Linux Systems Engineering Handbook**  
> **Subsystem**: Named Pipes (`mkfifo`), Bidirectional File Descriptors (`exec 3<>`), and Dijkstra Counting Semaphores

---

## 1. Architectural Mental Model: The Unthrottled Thundering Herd

In automated batch processing, scripts frequently process queues by dispatching work into background subshells:

```bash
# 💥 THE THUNDERING HERD ANTIPATTERN:
while IFS= read -r item; do
    process_item "$item" &
done < queue.txt
wait
```

If `queue.txt` contains 100 items, Bash immediately forks 100 concurrent subshell processes. In production systems, this triggers three catastrophic failures:
1. **Upstream Rate Limiting (HTTP 429)**: API gateways, microservices, and databases receive a burst spike, triggering automatic IP bans.
2. **Kernel Process Table Exhaustion**: 100+ processes rapidly consume OS PID slots toward `pid_max` and exhaust file descriptor limits (`ulimit -n`).
3. **CPU Context-Switching Thrashing**: The kernel scheduler spends more CPU time saving and restoring process register state than executing actual workload instructions.

---

## 2. Theory: Dijkstra Counting Semaphores in Pure Shell

A **Counting Semaphore** (formally introduced by Edsger Dijkstra) is a synchronization primitive maintaining an integer counter $S$ initialized to the maximum allowable concurrency $N$:

- **$P(S)$ / `wait` / `acquire`**: Decrement $S$. If $S \le 0$, block execution until a token becomes available.
- **$V(S)$ / `signal` / `release`**: Increment $S$. If other processes are blocked waiting for a token, wake one up.

```
                  ┌──────────────────────────────────────────────┐
                  │           Token Bucket FIFO (FD 3)           │
                  │           [ ● ]  [ ● ]  [ ● ]  [ ● ]         │
                  └───────────────┬──────────────────────────────┘
                                  │
                     read -u 3    │ (Acquire Token: blocks if empty)
                     Decrement    ▼
                               [ Worker Slot ]
                                  │
                                  │ (Runs background job in subshell)
                                  ▼
                     echo >&3     │ (Release Token: returns slot to pool)
                     Increment    ▼
                  ┌──────────────────────────────────────────────┐
                  │           Tokens Returned to Pool            │
                  └──────────────────────────────────────────────┘
```

Because external utilities like `xargs -P` or GNU `parallel` are frequently unavailable in minimal container base images (e.g. Alpine, Distroless, scratch), implementing a counting semaphore using native POSIX shell primitives is a core systems engineering capability.

---

## 3. Kernel Primitives & Mechanics

### 1. The Named Pipe (`mkfifo`) as a Token Queue
A POSIX named pipe (`FIFO`) is a kernel-managed circular ring buffer (`pipe_inode_info`). Bytes written to the pipe are read in strict First-In, First-Out order. Reading from an empty pipe naturally blocks the calling process in state `S` (interruptible sleep) until data is written.

### 2. Why `exec 3<>"$FIFO"` (Bidirectional Open) is Mandatory
A standard FIFO open for reading (`< "$FIFO"`) hits **`EOF` (End Of File)** the moment all writers close their descriptors, which causes `read` to return exit status 1 and breaks the loop.

Opening with **`3<>"$FIFO"`** tells the kernel to bind the descriptor for **both read and write (`O_RDWR`)**:
- Because the shell itself is registered as a permanent writer on FD 3, the kernel **never signals EOF on empty reads**.
- Instead, `read -u 3` pauses cleanly in the kernel wait queue until a token byte arrives.

### 3. The Anonymous Unlink Idiom (`rm -f "$FIFO"`)
In Unix filesystems, a file's inode and data buffers remain allocated in memory as long as at least one open file descriptor references them.
```bash
exec 3<>"$FIFO"
rm -f "$FIFO"
```
Unlinking the FIFO path immediately after opening it ensures that:
- The semaphore continues operating normally via FD 3.
- If the script crashes or is terminated with `SIGKILL`, no orphan FIFO nodes remain cluttering `/tmp` or the filesystem.

---

## 4. The Token Bucket Concurrency Loop

1. **Pre-seed $N$ Tokens**:
   ```bash
   for (( i=0; i<CONCURRENCY; i++ )); do
       echo >&3
   done
   ```
2. **Dispatch with Token Lifecycle**:
   ```bash
   while IFS= read -r item || [[ -n "$item" ]]; do
       read -u 3      # ACQUIRE: blocks if all N slots are currently active
       (
           run_task "$item"
           echo >&3   # RELEASE: returns token to FD 3 upon subshell completion
       ) &
   done < queue.txt
   wait
   exec 3>&-          # Close FD 3
   ```

---

## 5. Production Gotchas & Edge Cases

| Hazard | Cause | Prevention / Solution |
| :--- | :--- | :--- |
| **Token Leakage on Task Failure** | A background worker aborts under `set -e` before reaching `echo >&3`. The token is lost, eventually stalling the dispatcher in a permanent deadlock. | Wrap the release in a subshell trap or use: `( run_task "$item" \|\| true; echo >&3 ) &`. |
| **Descriptor Collision** | Using hardcoded file descriptor numbers (FD 3, 4) in complex scripts that already allocate custom descriptors. | In Bash 4.1+, allocate dynamic descriptors using `exec {sem_fd}<>"$FIFO"`. |
| **Subshell Inheritance Clutter** | Child tasks inherit open FD 3, which could be inadvertently closed or written to by child scripts. | Close FD 3 inside child tasks if invoking untrusted third-party binaries: `( exec 3>&-; third_party_tool )`. |

---

## 6. Curated Reading List & Authoritative Manuals

Study these authoritative system documentation sources to master POSIX semaphores and concurrency:

1. **`man 3 mkfifo` & `man 7 pipe`**
   - The Linux Programmer's Manual on named pipe creation, buffer limits (`PIPE_BUF`), and blocking semantics.
2. **`man 2 open`**
   - Review `O_RDWR` semantics on FIFO special files.
3. **`man 1 read`**
   - Read specifications for the Bash builtin `-u fd` option.
4. **`man 1 exec`**
   - Bash manual on redirection and custom file descriptor manipulation.
5. **POSIX IEEE Std 1003.1-2017**: Section `mkfifo`
   - POSIX specification on FIFO file creation and interoperability across Unix derivatives.
6. **The Linux Programming Interface (TLPI) by Michael Kerrisk**
   - *Chapter 44: Pipes and FIFOs* — Section 44.7 (FIFOs)
   - *Chapter 53: POSIX Semaphores* — Deep comparison between OS kernel semaphores and user-space token buckets.

---

## 7. Self-Assessment Checklist

Test your understanding of pure-shell counting semaphores:
- [ ] What is the purpose of opening a FIFO with `exec 3<>"$FIFO"` instead of standard read-only `< "$FIFO"`?
- [ ] Why does unlinking the FIFO pathname with `rm -f "$FIFO"` right after `exec 3<>` not break communication on FD 3?
- [ ] What happens to the dispatcher loop if a background worker process crashes before executing `echo >&3`?
- [ ] How does `read -u 3` behave when the FIFO buffer contains zero newline tokens?
- [ ] Why is `PIPE_BUF` atomicity (4,096 bytes) relevant when multiple subshells write tokens back to the FIFO concurrently?
