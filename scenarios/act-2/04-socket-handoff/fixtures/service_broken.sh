#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 2.04: THE UNIX SOCKET HANDOFF (IPC Service Controller)
# ==============================================================================
# Production init service controller managing an AF_UNIX domain socket daemon.
#
# CRISIS:
# INCIDENT-4091: Automated service restarts cause dropped client traffic and crash
# with 'Address already in use: daemon.sock'. If the previous instance crashed
# ungracefully or takes milliseconds to exit, the lingering socket file blocks
# bind(2). Clients attempting to connect immediately after restart receive
# 'Connection refused'.
#
# MISSION:
# Hardening 'service_ctl.sh' to implement clean Unix domain socket lifecycle management:
#   1. Gracefully terminate existing daemon (SIGTERM), polling until dead.
#   2. Clean up any lingering or stale socket files before starting.
#   3. Launch new daemon and poll socket readiness with client probes before returning.
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

# ------------------------------------------------------------------------------
# Action Implementations (BROKEN STATE)
# ------------------------------------------------------------------------------
start() {
    log_info "Initiating daemon startup..."

    # 💥 BROKEN: Fails with EADDRINUSE if a stale daemon.sock exists on disk!
    # Does not unlink lingering socket files before launching.
    python3 "$DAEMON_CMD" >/dev/null 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"

    # 💥 BROKEN: Returns immediately without verifying socket readiness!
    # Clients attempting to connect immediately encounter Connection Refused.
    log_info "Daemon spawned with PID $new_pid."
    echo "SERVICE_STARTED"
}

stop() {
    log_info "Initiating daemon shutdown..."

    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE")"
        log_info "Terminating daemon PID $pid..."
        # 💥 BROKEN: Hard kill -9 prevents cleanup handlers from unlinking socket
        # and does not wait for process to fully exit!
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi

    echo "SERVICE_STOPPED"
}

restart() {
    log_info "Initiating service restart sequence..."
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
