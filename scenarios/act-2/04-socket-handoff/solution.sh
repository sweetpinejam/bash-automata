#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 2.04 (The Unix Socket Handoff)
# ==============================================================================
# Unix domain socket service controller with graceful shutdown and readiness probing.
# ==============================================================================

set -euo pipefail

PID_FILE="daemon.pid"
SOCKET_FILE="daemon.sock"
DAEMON_CMD="daemon.py"
CLIENT_CMD="client.py"
STATUS_FILE="service_status.json"

log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] $*" >&2
}

log_warn() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] $*" >&2
}

log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [ERROR] $*" >&2
}

stop() {
    log_info "Initiating graceful daemon shutdown..."

    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE")"
        log_info "Sending SIGTERM to daemon PID $pid..."
        kill -TERM "$pid" 2>/dev/null || true

        # Wait up to 1.0 second for daemon to exit cleanly
        for (( i=0; i<20; i++ )); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.05
        done
        rm -f "$PID_FILE"
    fi

    # Unlink any lingering socket file to guarantee clean state
    rm -f "$SOCKET_FILE"
    log_info "Daemon stopped and resources reclaimed."
    echo "SERVICE_STOPPED"
}

start() {
    log_info "Initiating daemon startup..."

    # Guard: Unlink stale socket file before starting to prevent EADDRINUSE on bind()
    rm -f "$SOCKET_FILE"

    python3 "$DAEMON_CMD" >/dev/null 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"

    log_info "Daemon spawned with PID $new_pid. Polling socket readiness..."

    # Readiness wait loop: verify socket inode existence AND protocol connectivity
    local ready=false
    for (( i=0; i<40; i++ )); do
        if [[ -S "$SOCKET_FILE" ]] && python3 "$CLIENT_CMD" >/dev/null 2>&1; then
            ready=true
            break
        fi
        sleep 0.05
    done

    if ! $ready; then
        log_error "Daemon failed to bind active socket within timeout window!"
        kill -9 "$new_pid" 2>/dev/null || true
        rm -f "$PID_FILE" "$SOCKET_FILE"
        exit 1
    fi

    log_info "Daemon socket verified ready for incoming client traffic."
    echo "SERVICE_STARTED"
}

restart() {
    log_info "Initiating zero-drop service restart sequence..."
    stop
    start
    echo "RESTART_COMPLETE"
}

status() {
    if [[ -f "$PID_FILE" ]] && [[ -S "$SOCKET_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE")"
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Service is running (PID: $pid, Socket: $SOCKET_FILE)."
            echo "STATUS_RUNNING"
            return 0
        fi
    fi
    log_info "Service is stopped."
    echo "STATUS_STOPPED"
    return 1
}

# ------------------------------------------------------------------------------
# CLI Dispatcher
# ------------------------------------------------------------------------------
case "${1:-status}" in
    start)   start ;;
    stop)    stop ;;
    restart) restart ;;
    status)  status ;;
    *)
        echo "Usage: service_ctl.sh {start|stop|restart|status}" >&2
        exit 1
        ;;
esac
