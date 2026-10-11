# Structural Scaffolding: Unix Domain Socket Lifecycle & Readiness Wait

To prevent `EADDRINUSE` bind failures and connection drops during service restarts, structure the service controller with graceful shutdown, stale inode cleanup, and a readiness barrier:

---

## Pattern: Graceful Socket Lifecycle Controller

```bash
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
    # Clean up residual socket file:
    rm -f "$SOCKET_FILE"
    echo "SERVICE_STOPPED"
}

start() {
    # Guard against stale crash socket files:
    rm -f "$SOCKET_FILE"

    python3 daemon.py >/dev/null 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"

    # Readiness probe: Poll until socket file exists AND client connects:
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

---

## Verifying Socket Health

Inspect socket file and communication directly from the terminal:
```bash
# Verify socket inode type (should show 'socket'):
stat -c "%F %A %n" daemon.sock

# Send test message over socket:
python3 client.py
```
