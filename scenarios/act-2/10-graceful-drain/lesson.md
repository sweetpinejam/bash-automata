# Tactical Field Manual 2.10: The Graceful Drain Teardown

> **Incident Class**: Container Rollout Evictions, In-Flight State Corruption & Asynchronous Signal Latches  
> **Key Tooling**: `trap`, POSIX Signal Dispositions, Safe Transaction Boundaries, Orchestrator Grace Periods

---

## 1. Incident Post-Mortem & Architecture Context

In modern cloud platforms (Kubernetes, AWS ECS, Nomad, Docker Swarm), application deployments are continuous and dynamic. During a rolling deployment or node drain:
1. The orchestrator updates the replica set and marks old pods for eviction.
2. The orchestrator sends `SIGTERM` (signal 15) to PID 1 inside the container.
3. A countdown timer begins: `terminationGracePeriodSeconds` (default: 30 seconds in Kubernetes).
4. If the container terminates with exit code 0 within the grace window, the pod is removed cleanly.
5. If the container fails to terminate before the countdown expires, the orchestrator forcefully sends `SIGKILL` (signal 9).

### The Vulnerability: Unhandled `SIGTERM` & Severed Transactions
When a queue consumer or payment processing worker lacks an explicit signal handler for `SIGTERM`:
- The default Linux kernel disposition for `SIGTERM` is **immediate process termination**.
- If `SIGTERM` arrives while the worker is halfway through a 3-step database update (e.g. between debiting an account and crediting a ledger), the worker process is killed instantly.
- The in-flight transaction is severed, leaving orphaned records, unreleased database locks, and data inconsistencies that require manual database surgery.

---

## 2. Kernel & POSIX Mental Models

### A. Linux Signal Delivery & Disposition
When the kernel delivers an asynchronous signal to a process:
- The kernel suspends the thread's regular execution flow.
- It pushes an architectural signal frame onto the stack.
- It redirects the instruction pointer (`%rip` on x86_64) to the registered user-space signal handler.
- Once the handler returns, execution resumes at the previous instruction.

Signals have default dispositions defined in POSIX:
| Signal | Number | Default Disposition | Production Role |
| :--- | :--- | :--- | :--- |
| `SIGINT` | 2 | Terminate | Interactive interrupt (`Ctrl+C`) |
| `SIGTERM` | 15 | Terminate | Graceful termination request from orchestrator |
| `SIGQUIT` | 3 | Terminate + Core Dump | Teardown with debugging core dump |
| `SIGKILL` | 9 | Unconditional Termination | Kernel destroys process; cannot be trapped |

### B. The Signal Latch Architecture (Async-Signal-Safety)
A major anti-pattern in systems programming is performing complex, multi-step teardown operations (such as making network RPC calls, unmounting filesystems, or writing complex JSON telemetry) directly inside the signal trap handler:
- Signal handlers run asynchronously and can interrupt code at any instruction.
- Non-reentrant library functions (like memory allocators or buffered I/O streams) can deadlock if interrupted by a signal handler that calls the same function.

**The Golden Standard: The Signal Latch**
Instead of executing heavy logic in the trap, the trap handler executes a single, atomic operation: **it flips a boolean flag** (`draining=true`).
```bash
draining=false
trap 'draining=true' TERM INT
```
The main loop continues executing linearly. At well-defined **safe transaction boundaries**, the loop inspects `$draining`:
1. If true before dequeuing: **Refuse new work**.
2. In-flight transaction: **Runs to completion without interruption**.
3. If true after committing: **Break loop and execute clean shutdown**.

### C. The PID 1 Problem in Minimal Containers
In Linux, the process with PID 1 possesses unique kernel behavior:
- Unlike regular processes, the kernel will NOT apply default signal actions (like terminating on `SIGTERM`) to PID 1 if PID 1 has not explicitly installed a handler for that signal.
- If a container runs a binary that does not handle `SIGTERM` as PID 1, orchestrator termination signals are ignored until the 30-second timeout expires and `SIGKILL` executes.
- In shell-based container entrypoints, registering explicit `trap ... TERM INT` handlers ensures signals are caught immediately.

---

## 3. Two-Phase Graceful Drain State Machine

```
               [Kubernetes / Orchestrator Control Plane]
                                  │
                                  ├─► Dispatches SIGTERM (Pod Eviction)
                                  ▼
                     [Worker Signal Trap Handler]
                    trap 'draining=true' TERM INT
                                  │
                     ┌────────────┴────────────┐
                     ▼                         ▼
             [draining = false]        [draining = true]
                     │                         │
     ┌───────────────┴───────────────┐         ▼
     │ 1. Check $draining            │   Refuse new tasks
     │    (false: dequeue job)       │   from queue
     │                               │         │
     │ 2. TX_START                   │         │
     │ 3. Execute atomic transaction │         │
     │    (SIGTERM arrives here!)    │         │
     │    - Flag latched to true     │         │
     │    - Work finishes cleanly!   │         │
     │ 4. TX_COMMITTED               │         │
     │                               │         │
     │ 5. Check $draining            │         │
     │    (true: break loop!) ◄──────┴─────────┘
     └───────────────┬─────────────────────────┘
                     │
                     ▼
             [Teardown Phase]
             echo "DRAIN_COMPLETED" > drain.log
             rm -f worker.pid
             exit 0 (Orchestrator records clean exit)
```

---

## 4. Syntax & Primitive Reference

| Primitive | Action | Description |
| :--- | :--- | :--- |
| `trap 'action' SIGNALS` | Register Signal Handler | Binds shell string action to specified signals |
| `trap '' SIGNALS` | Ignore Signal | Tells kernel to ignore the signal |
| `trap - SIGNALS` | Reset Signal | Restores default operating system disposition |
| `trap 'action' EXIT` | Exit Cleanup Hook | Executes whenever the shell exits (normal or error) |
| `$$` | Current Process PID | Emitted to `worker.pid` for orchestrator tracking |
| `read -r` | Safe Queue Ingestion | Reads raw lines without escaping backslashes |

---

## 5. Production Implementation Gotchas

### 1. Long-Running Workloads vs Grace Period Expiration
If an individual transaction takes 45 seconds to commit, but the Kubernetes `terminationGracePeriodSeconds` is set to 30 seconds, the orchestrator will send `SIGKILL` before the in-flight job finishes!
- Always calibrate `terminationGracePeriodSeconds` to exceed your 99.9th percentile transaction duration.
- For jobs with unbounded latency, break work into smaller atomic checkpoints.

### 2. Signal Storms (Duplicate `SIGTERM` / `SIGINT`)
In production, monitoring agents or operators may send multiple consecutive `SIGTERM` signals. Because the signal latch (`draining=true`) is an idempotent assignment, duplicate signals do not corrupt the state machine or trigger multiple teardowns.

### 3. Lingering Child Processes During Drain
If the worker spawns background subprocesses (`&`), terminating the parent shell does not automatically terminate detached children. Ensure that child subshells are tracked and reaped with `wait` or signaled in the cleanup routine.

---

## 6. Self-Assessment Checklist

1. [ ] **Signal Interception**: Does the worker register explicit traps for both `SIGTERM` and `SIGINT`?
2. [ ] **In-Flight Atomicity**: If a signal arrives while a transaction is actively committing, does that transaction finish completely with a matching `TX_COMMITTED` record?
3. [ ] **No Work Ingestion Post-Signal**: Does the worker refuse to dequeue new items once the drain flag is latched?
4. [ ] **Clean Orchestrator Teardown**: Does the worker write `DRAIN_COMPLETED` to `drain.log` and terminate with return code `0`?
5. [ ] **Resource Cleanliness**: Is the PID file (`worker.pid`) cleanly unlinked upon termination?

---

## 7. Curated Reading List & References

- **Linux Manual Pages**:
  - `man 1 bash(1)` - GNU Bash manual (Sections: *Signals*, *trap builtin*)
  - `man 2 sigaction(2)` - Examine and change a signal action (POSIX signal delivery)
  - `man 7 signal(7)` - Overview of Linux signals and async-signal-safe functions
- **POSIX IEEE Std 1003.1-2017**:
  - `Shell Command Language: Section 2.14 (Special Built-In Utilities: trap)`
  - `System Interfaces: sigaction, signal`
- **Container Architecture & Kubernetes Standards**:
  - *Kubernetes Documentation*: *Pods - Pod Lifecycle and Container Termination* (`https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination`)
  - *Docker Best Practices*: *Handling Signals in Containers (PID 1 and init systems)*
- **The Linux Programming Interface (TLPI) by Michael Kerrisk**:
  - *Chapter 20: Signals: Fundamental Concepts*
  - *Chapter 21: Signals: Signal Handlers* (Async-signal safety, reentrancy, signal flags)
- **Production Systems Engineering**:
  - *Brendan Gregg, "BPF Performance Tools"* - Tracing signal delivery with `syscount` and `killsnoop`
