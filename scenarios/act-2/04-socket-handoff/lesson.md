# Tactical Field Manual: The Unix Socket Handoff (`AF_UNIX` Lifecycle & Readiness Probing)

> **POSIX & Linux Systems Engineering Handbook**  
> **Subsystem**: Unix Domain Sockets (`AF_UNIX`), Filesystem Inode Bindings (`S_IFSOCK`), and Process Liveness Polling (`kill -0`)

---

## 1. Architectural Mental Model: The Unix Domain Socket Lifecycle Trap

Unix Domain Sockets (`AF_UNIX` or `AF_LOCAL`) provide high-throughput, low-latency Inter-Process Communication (IPC) by passing data buffers entirely within the Linux kernel page cache without traversing network device drivers or IP stacks.

Unlike TCP sockets (which bind to abstract network ports managed purely in kernel tables), a Unix domain socket binds to a physical path in the filesystem namespace:

```
               Process Space                     Filesystem Namespace (VFS)
        ┌─────────────────────────┐             ┌─────────────────────────┐
        │       Daemon (C/Py)     │             │       daemon.sock       │
        │ socket(AF_UNIX)         │             │   (Inode: S_IFSOCK)     │
        │ bind("daemon.sock") ────┼────────────▶│ Mode: srwxr-xr-x        │
        │ listen(16)              │             │ References socket buffer│
        └─────────────────────────┘             └─────────────────────────┘
```

### The "Address Already in Use" Trap (`EADDRINUSE`)
When a server calls `bind(2)` on a filesystem path:
1. If the file `daemon.sock` **already exists** on disk—even if the previous owning process crashed or was killed hours ago—the Linux kernel strictly refuses to bind and returns **`EADDRINUSE` (Errno 98: Address already in use)**.
2. When a process receives an ungraceful termination (`SIGKILL`, kernel OOM kill, or segfault), the kernel closes the underlying file descriptor, but **does not remove the pathname directory entry from the filesystem.**
3. The stale socket file lingers on disk indefinitely as an orphaned inode. Any subsequent restart attempt fails immediately.

### The Readiness Race Condition (`Connection Refused`)
When an automation script restarts a service naively:
```bash
kill "$OLD_PID"
python3 daemon.py &
echo "RESTART_COMPLETE"  # 💥 PREMATURE RETURN!
```
The script returns before the new daemon process has completed interpreter startup, created the socket file, and called `listen(2)`. Downstream client processes querying the service immediately after restart receive **`ECONNREFUSED` (Connection refused)**, dropping customer traffic.

---

## 2. Architecture: Zero-Drop Socket Lifecycle Management

A production-grade service controller must implement a strict three-phase lifecycle:

```
  ┌─────────────────────────────────────────────────────────────────┐
  │ 1. STOP PHASE (Graceful Drain & Unlink)                         │
  │    kill -TERM "$pid"                                            │
  │    Loop: kill -0 "$pid" || break (Wait up to 1.0s for exit)     │
  │    rm -f daemon.sock (Clean up residual socket file)            │
  └───────────────────────────────┬─────────────────────────────────┘
                                  │
  ┌───────────────────────────────▼─────────────────────────────────┐
  │ 2. START PHASE (Stale Cleanup & Background Spawn)               │
  │    rm -f daemon.sock (Guaranteed clean slate for bind())        │
  │    python3 daemon.py &                                          │
  │    Record new PID in daemon.pid                                 │
  └───────────────────────────────┬─────────────────────────────────┘
                                  │
  ┌───────────────────────────────▼─────────────────────────────────┐
  │ 3. READINESS BARRIER (Two-Phase Verification)                   │
  │    Phase A: [[ -S daemon.sock ]] (Verify socket inode exists)   │
  │    Phase B: python3 client.py (Verify listen() accepts conns)    │
  │    Loop until verified or timeout (2.0s)                        │
  └───────────────────────────────┬─────────────────────────────────┘
                                  │
  ┌───────────────────────────────▼─────────────────────────────────┐
  │ 4. SAFE RETURN                                                  │
  │    echo "RESTART_COMPLETE" (Zero client connection drops!)      │
  └─────────────────────────────────────────────────────────────────┘
```

---

## 3. Kernel Primitives & Shell Verification Mechanics

### 1. The `-S` Socket Inode Test
In POSIX shell syntax, the `-S` operator queries the VFS inode metadata via `stat(2)`:
```bash
[[ -S "$SOCKET_FILE" ]]
```
Returns `true` if and only if the target file exists AND its file mode flags indicate a socket (`S_IFSOCK` in `stat.st_mode`).

### 2. Process Existence Polling via Signal 0 (`kill -0`)
In POSIX systems, passing signal number `0` to `kill(2)` performs error-checking and permission validation **without sending an actual signal**:
```bash
kill -0 "$pid" 2>/dev/null
```
- Returns exit code `0` if a process with that PID exists and can receive signals.
- Returns exit code `1` (or `ESRCH`) if the process has completely terminated and exited the process table.

### 3. Readiness Handshake Probe
Checking `[[ -S "$SOCKET_FILE" ]]` confirms the inode exists, but the daemon may still be initializing internal structures before calling `listen()`. Pinging the socket with a real client command guarantees the server is actively accepting connections:
```bash
if [[ -S "$SOCKET_FILE" ]] && python3 client.py >/dev/null 2>&1; then
    ready=true
fi
```

---

## 4. Production Gotchas & Edge Cases

| Hazard | Cause | Prevention / Solution |
| :--- | :--- | :--- |
| **Path Length Limitation (`sun_path`)** | In the Linux kernel (`linux/un.h`), `sockaddr_un.sun_path` is strictly limited to **108 bytes**! Long pathnames cause `bind(2)` to fail with `ENAMETOOLONG`. | Place runtime socket files in short paths (e.g. `/run/service.sock` or `/tmp/service.sock`). |
| **Zombie Process Hangs** | Process terminated but parent hasn't reaped it; `kill -0` returns true indefinitely. | Combine process polling with a timeout loop (e.g. 20 iterations of 0.05s). |
| **Permissions (`umask`) Blocking Clients** | Sockets created with restrictive default umask (`077`) prevent non-root clients from connecting with `EACCES`. | Explicitly set permissions after creation: `chmod 0660 "$SOCKET_FILE"`. |
| **Abstract Namespace Alternative** | In Linux, prefixing a socket path with a null byte (`\0path`) binds in the abstract namespace without creating filesystem files. | Abstract sockets auto-clean on process death, but lack filesystem permission access controls. |

---

## 5. Curated Reading List & Authoritative Manuals

Study these authoritative system documentation sources to master Unix domain sockets:

1. **`man 7 unix`**
   - The Linux Programmer's Manual on Unix domain sockets, addressing formats, filesystem mapping, and permissions.
2. **`man 2 bind` & `man 2 listen` & `man 2 accept`**
   - Detailed specifications on socket creation, `EADDRINUSE` failure conditions, and backlog queues.
3. **`man 2 kill`**
   - Review signal number `0` specifications for process liveness verification.
4. **`man 1 test`**
   - Read specifications for the `-S` socket test operator in standard POSIX shells.
5. **The Linux Programming Interface (TLPI) by Michael Kerrisk**
   - *Chapter 57: Sockets: Unix Domain* — Section 57.1 (Unix Domain Socket Addresses), Section 57.3 (Unix Domain Stream Sockets), and Section 57.6 (Permissions and Ownership).
   - *Chapter 20: Signals: Fundamental Concepts* — Section 20.5 (Checking for Process Existence with `kill(pid, 0)`).

---

## 6. Self-Assessment Checklist

Test your understanding of Unix domain socket lifecycles:
- [ ] Why does `bind("daemon.sock")` fail with `EADDRINUSE` if an old socket file exists on disk even though no process is running?
- [ ] Why does `SIGKILL` leave residual socket files behind on disk while graceful `SIGTERM` allows clean unlinking?
- [ ] What is the exact purpose of `kill -0 "$PID"` in a graceful shutdown loop?
- [ ] Why is checking `[[ -S "$SOCKET_FILE" ]]` alone insufficient to guarantee that a client can immediately send queries?
- [ ] What is the maximum character length for a Unix domain socket path in Linux (`sockaddr_un.sun_path`)?
