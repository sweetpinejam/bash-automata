# Tactical Field Manual: The Command Dispatcher (`case` Routing & Daemon Control)

## 1. Systems Mental Model: The `if/elif` Anti-Pattern in CLI Routing
In command-line utilities and system daemon control wrappers, routing operations with `if/elif` quickly deteriorates into unmaintainable spaghetti:
```bash
# ❌ FRAGILE NESTED IF/ELIF ROUTING:
if [ "$action" = "start" ]; then
    ...
elif [ "$action" = "stop" ]; then
    ...
elif [ "$action" = "-h" ] || [ "$action" = "--help" ] || [ "$action" = "help" ]; then
    ...
fi
# What if the user typed "restart"? What if they typed a typo? It fails silently with exit 0!
```

### The Canonical Solution: The Bash `case` Statement
The `case` construct is Bash's pattern-matching multi-way branch. It provides:
1. **Zero Subprocess Pattern Matching**: Uses shell wildcards (`*`, `?`, `|`) in memory.
2. **Explicit Fallthrough Control**: Terminated by `;;`.
3. **Mandatory Catch-All Defense (`*`)**: Guarantees that unhandled actions are rejected with a non-zero exit code.

```bash
case "$action" in
    start)
        echo "Starting service..."
        ;;
    stop)
        echo "Stopping service..."
        ;;
    -h|--help|help)
        echo "Usage: $0 {start|stop|status}"
        exit 0
        ;;
    *)
        echo "Error: Unknown action '$action'" >&2
        exit 1
        ;;
esac
```

---

## 2. Syntax Anatomy: Branch Terminators in Bash

Unlike languages where `break` is optional, in POSIX shell every branch must specify a terminator:

| Terminator | Behavior | Standard | Use Case |
| :--- | :--- | :--- | :--- |
| **`;;`** | **Break** (Terminate `case`) | POSIX | 99% of CLI command dispatchers |
| **`;&`** | **Fall-through** (Executes next branch body unconditionally) | Bash 4.0+ | Cascading flag defaults |
| **`;;&`** | **Continue testing** (Tests remaining patterns) | Bash 4.0+ | Multi-filter audit rules |

### Pattern Alternation (`|`)
You can group multiple aliases or flags in a single branch using the pipe `|` symbol:
```bash
-h|--help|help)
    show_usage
    exit 0
    ;;
```

---

## 3. Production Daemon Lifecycle: PID Files & `kill -0`

In Linux systems administration, a daemon wrapper manages a **PID file** (e.g., `service.pid`). Managing PID files safely requires understanding the **Signal 0 Probing Idiom**:

### What is `kill -0 "$pid"`?
Signal 0 is a special pseudo-signal:
```bash
if kill -0 "$pid" 2>/dev/null; then
    echo "Process $pid is alive and running."
else
    echo "Process $pid does not exist in the kernel process table."
fi
```
1. The kernel does not send a real signal; the target process is not affected.
2. The kernel verifies whether the calling process has permission to send signals to `$pid`, and whether `$pid` currently exists in `/proc`.
3. Returns exit code 0 if the process is alive; returns exit code 1 if the process is dead.

### The Stale PID File Disaster:
If a server crashes or a container restarts, `service.pid` remains on disk containing an old PID:
* If your script blindly trusts `[[ -f service.pid ]]`, it falsely claims the service is running!
* If the old PID has been recycled by the kernel for an unrelated process (e.g. `sshd`), calling `kill "$pid"` might kill an innocent system daemon!
* **The Rule**: Always verify PID validity with `kill -0 "$pid"` before reporting running status or sending signals.

---

## 4. Architectural Diagram: Daemon Supervisor State Machine

```
[ Invocations: ./service_ctl.sh <action> ]
                         │
                         ▼
        [ case "$ACTION" in ... esac ]
   ┌───────────────┬───────────────┬───────────────┬───────────────┐
   ▼               ▼               ▼               ▼               ▼
[ start ]       [ stop ]        [ status ]      [ help ]        [ * ]
   │               │               │               │               │
   ├─ Check PID    ├─ Check PID    ├─ Check PID    ├─ Print usage  └─ Print error
   │  alive?       │  alive?       │  - Alive?     └─ Exit 0          to stderr
   │  Yes -> Err   │  Yes -> TERM  │    -> RUNNING (0)                Exit 1
   │  No -> Spawn  │  No  -> Clear │  - Dead?
   │        Record │  Clear PID    │    -> STALE (2)
   │        Exit 0 │  Exit 0       │  - Missing?
   │               │               │    -> STOPPED (3)
```

---

## 5. Self-Assessment Checklist
Before modifying `service_ctl.sh`:

1. **Why is `case` preferred over nested `if/elif` for command dispatchers?**
   * *Answer*: `case` provides cleaner syntax, built-in pattern alternation (`-h|--help`), and forces explicit wildcard catch-all handling.
2. **What does `kill -0 "$pid"` do?**
   * *Answer*: It performs a kernel check to see if process `$pid` is currently alive without sending a terminating signal.
3. **What is a "stale PID file"?**
   * *Answer*: A PID file that remains on disk after the process died unexpectedly.
4. **Why must every `case` branch terminate with `;;`?**
   * *Answer*: In POSIX shell, `;;` indicates the end of a branch's command list and terminates evaluation of the `case` statement.
5. **What should happen when an unhandled command reaches the `*` pattern?**
   * *Answer*: The script must output an informative error message to `stderr` and exit with a non-zero exit code (typically 1).

---

## 6. Mission Objectives
Implement `service_ctl.sh` as a production daemon supervisor:
1. Accept action as `$1` (default: `help`).
2. Implement routing strictly using `case "$action" in ... esac`.
3. Support the following command routes:
   - `start`:
     - If PID file exists and process is alive: print `ERROR: Service already running (pid=<PID>)` and exit 1.
     - If PID file exists but process is dead: remove stale PID file.
     - Start background worker (`sleep 300 &`), record `$!` into `service.pid`.
     - Print `SERVICE_STARTED: pid=<PID>` and exit 0.
   - `stop`:
     - If PID file does not exist: print `ERROR: Service is not running` and exit 1.
     - Read PID. If alive: send `SIGTERM` (`kill "$pid"`), remove `service.pid`, print `SERVICE_STOPPED: pid=<PID>`, exit 0.
     - If dead: clean stale `service.pid`, print `SERVICE_STOPPED: cleaned stale pid`, exit 0.
   - `restart`:
     - Execute stop logic (if running), then start. Print `SERVICE_RESTARTED: pid=<PID>`, exit 0.
   - `status`:
     - If PID file exists and process is alive: print `STATUS: RUNNING (pid=<PID>)` and exit 0.
     - If PID file exists and process is dead: print `STATUS: STALE_PID (pid=<PID>)` and exit 2.
     - If PID file does not exist: print `STATUS: STOPPED` and exit 3.
   - `-h` | `--help` | `help`:
     - Print usage information and exit 0.
   - `*`:
     - Print `Error: Unknown action '<action>'` to `stderr` and exit 1.
