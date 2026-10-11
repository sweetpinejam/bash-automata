#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.11 (The Command Dispatcher)
# ==============================================================================
set -euo pipefail

PID_FILE="service.pid"
ACTION="${1:-help}"

is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

start_service() {
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "ERROR: Service already running with PID $pid" >&2
        exit 1
    fi

    # Clean stale PID file if present
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi

    # Start background process with detached streams
    sleep 300 >/dev/null 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"
    echo "SERVICE_STARTED: pid=$new_pid"
}

stop_service() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "ERROR: Service is not running" >&2
        exit 1
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
        echo "SERVICE_STOPPED: pid=$pid"
    else
        rm -f "$PID_FILE"
        echo "SERVICE_STOPPED: cleaned stale pid"
    fi
}

check_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "STATUS: RUNNING (pid=$pid)"
            exit 0
        else
            echo "STATUS: STALE_PID (pid=$pid)"
            exit 2
        fi
    else
        echo "STATUS: STOPPED"
        exit 3
    fi
}

case "$ACTION" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        if [[ -f "$PID_FILE" ]]; then
            stop_service
        fi
        start_service
        ;;
    status)
        check_status
        ;;
    -h|--help|help)
        echo "Usage: $0 {start|stop|restart|status|help}"
        exit 0
        ;;
    *)
        echo "Error: Unknown action '$ACTION'" >&2
        echo "Run '$0 --help' for usage." >&2
        exit 1
        ;;
esac
