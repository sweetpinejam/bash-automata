# Code Blueprint: Unix Domain Socket Lifecycle & Readiness Wait

Manage Unix domain socket daemons cleanly without `EADDRINUSE` errors or connection drops:

```bash
# Blueprint Pattern:
PID_FILE="daemon.pid"
SOCKET_FILE="daemon.sock"

stop() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    kill -TERM "$pid" 2>/dev/null || true

    # Wait up to 1s for process to exit cleanly:
    for (( i=0; i<20; i++ )); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.05
    done
    rm -f "$PID_FILE"
  fi
  # Clean up any residual socket file:
  rm -f "$SOCKET_FILE"
  echo "SERVICE_STOPPED"
}

start() {
  # Guard: Stale socket files cause bind() to fail with EADDRINUSE:
  rm -f "$SOCKET_FILE"

  python3 daemon.py &
  local new_pid=$!
  echo "$new_pid" > "$PID_FILE"

  # Readiness probe: Poll until socket file exists and is active (up to 2s):
  local ready=false
  for (( i=0; i<40; i++ )); do
    if [[ -S "$SOCKET_FILE" ]] && python3 client.py >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 0.05
  done

  if ! $ready; then
    echo "ERROR: Daemon failed to bind socket within timeout!" >&2
    kill -9 "$new_pid" 2>/dev/null || true
    exit 1
  fi

  echo "SERVICE_STARTED"
}

restart() {
  stop
  start
  echo "RESTART_COMPLETE"
}
```

> **Key Rule**: The `-S` test operator (`[[ -S "$SOCKET_FILE" ]]`) tests if a file exists and is a Unix domain socket. Polling readiness before returning guarantees zero 502/refused connections.
