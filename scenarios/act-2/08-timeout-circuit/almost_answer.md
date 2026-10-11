# Code Blueprint: Pure Bash Timeout Circuit Breaker

Implement timeout execution in minimal environments without the GNU `timeout` utility:

```bash
# Blueprint Pattern:
run_with_timeout() {
  local timeout_sec="$1"
  shift

  # 1. Run target command in background subshell:
  "$@" &
  local cmd_pid=$!

  # 2. Run timer watchdog in parallel background subshell:
  (
    sleep "$timeout_sec"
    # Escalate kill on target process if timer expires:
    kill -TERM "$cmd_pid" 2>/dev/null || true
    sleep 0.1
    kill -9 "$cmd_pid" 2>/dev/null || true
  ) &
  local timer_pid=$!

  # 3. Wait on command completion:
  local status=0
  if wait "$cmd_pid" 2>/dev/null; then
    # Command completed within timeout: cancel timer
    kill "$timer_pid" 2>/dev/null || true
    wait "$timer_pid" 2>/dev/null || true
    return 0
  else
    status=$?
    # Command failed or was killed by watchdog
    kill "$timer_pid" 2>/dev/null || true
    wait "$timer_pid" 2>/dev/null || true
    return 124
  fi
}
```

> **Key Rule**: Always kill the background timer (`kill "$timer_pid"`) when the main command completes early. Otherwise, orphaned `sleep` subshells will accumulate in the process table.
