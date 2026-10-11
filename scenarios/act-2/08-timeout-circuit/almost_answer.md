# Structural Scaffolding: Scenario 2.08 (The Cascading Timeout Shield)

> **Objective**: Implement a pure Bash watchdog circuit breaker (`run_with_timeout`) without relying on the GNU coreutils `timeout` utility.

---

### Architectural Pattern: Dual-Subshell Concurrency

In minimal container runtimes where the `timeout` binary is missing, timeout handling requires running two parallel asynchronous jobs:
1. **Worker Command Subshell**: Executes the target program and provides its PID via `$!`.
2. **Watchdog Timer Subshell**: Sleeps for the specified duration and sends termination signals if the worker has not completed.

```
       [Parent Shell Coordinator]
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
  [Worker Command]    [Watchdog Timer]
  "$@" &              ( sleep $timeout; kill -TERM $cmd_pid ) &
  cmd_pid=$!          timer_pid=$!
         │                   │
         └─────────┬─────────┘
                   ▼
          wait "$cmd_pid"
```

---

### Structural Skeleton

```bash
run_with_timeout() {
    local timeout_sec="$1"
    shift

    # 1. Spawn target command asynchronously in the background
    "$@" &
    local cmd_pid=$!

    # 2. Spawn watchdog timer in a parallel subshell
    (
        sleep "$timeout_sec"
        # Escalation sequence: check if process is still running with kill -0
        if kill -0 "$cmd_pid" 2>/dev/null; then
            # Send polite SIGTERM first
            kill -TERM "$cmd_pid" 2>/dev/null || true
            sleep 0.2
            # Escalate to uncatchable SIGKILL if still present
            if kill -0 "$cmd_pid" 2>/dev/null; then
                kill -KILL "$cmd_pid" 2>/dev/null || true
            fi
        fi
    ) &
    local timer_pid=$!

    # 3. Synchronize on worker completion
    local cmd_exit=0
    if wait "$cmd_pid" 2>/dev/null; then
        cmd_exit=0
    else
        cmd_exit=$?
    fi

    # 4. Determine whether the timer fired or the process finished naturally
    if kill -0 "$timer_pid" 2>/dev/null; then
        # Worker completed BEFORE the watchdog timer expired:
        # Cancel watchdog and reap sleep processes to avoid orphan accumulation
        pkill -P "$timer_pid" 2>/dev/null || true
        kill "$timer_pid" 2>/dev/null || true
        wait "$timer_pid" 2>/dev/null || true
        return "$cmd_exit"
    else
        # Watchdog timer expired and fired signals:
        wait "$timer_pid" 2>/dev/null || true
        return 124
    fi
}
```

---

### Key Operational Rules

1. **Reap Watchdog Processes Promptly**:
   If the worker command finishes in 50 milliseconds, failing to kill `$timer_pid` leaves a background `sleep` command running for the remainder of the timeout window. Always cancel and reap the timer subshell with `wait "$timer_pid"`.

2. **Standard POSIX Timeout Exit Code**:
   GNU `timeout` and standard POSIX conventions designate exit status `124` for timed-out commands.

3. **Two-Stage Signal Escalation**:
   Always attempt graceful termination (`SIGTERM` / signal 15) before escalating to unconditional termination (`SIGKILL` / signal 9), allowing target applications to flush buffers and close network sockets if possible.
