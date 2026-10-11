#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.11: The Command Dispatcher (Production Daemon Supervisor)
# ==============================================================================
# INSTRUCTIONS:
# Implement a robust daemon supervisor CLI in pure Bash.
#
# HARD CONSTRAINT:
# All command routing MUST use 'case "$action" in ... esac'.
#
# Arguments:
#   $1 = action (start, stop, restart, status, -h, --help, help)
#
# Requirements:
# 1. PID file: "service.pid".
# 2. Check process liveness via 'kill -0 "$pid" 2>/dev/null'.
# 3. Actions:
#    - "start":
#        If running: print error to stderr and exit 1.
#        If stale PID: remove stale PID file.
#        Start background process: '(sleep 300 &) >/dev/null 2>&1' or 'sleep 300 &'
#        Save $! to service.pid.
#        Print "SERVICE_STARTED: pid=$pid" and exit 0.
#    - "stop":
#        If no PID file: print error to stderr and exit 1.
#        If process alive: kill "$pid", remove service.pid, print "SERVICE_STOPPED: pid=$pid", exit 0.
#        If process dead: remove service.pid, print "SERVICE_STOPPED: cleaned stale pid", exit 0.
#    - "restart":
#        Stop (if running) then start. Print "SERVICE_RESTARTED: pid=$pid", exit 0.
#    - "status":
#        If running: print "STATUS: RUNNING (pid=$pid)", exit 0.
#        If stale PID: print "STATUS: STALE_PID (pid=$pid)", exit 2.
#        If not running: print "STATUS: STOPPED", exit 3.
#    - "-h" | "--help" | "help":
#        Print usage and exit 0.
#    - "*":
#        Print error to stderr and exit 1.
# ==============================================================================
set -euo pipefail

PID_FILE="service.pid"
ACTION="${1:-help}"

# Helper function to check if PID in $PID_FILE is currently running in the kernel
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

# TODO: Refactor routing into a case "$ACTION" in ... esac dispatcher:
case "$ACTION" in
    start)
        # TODO: Handle start logic
        echo "SERVICE_NOT_IMPLEMENTED"
        exit 1
        ;;
    stop)
        # TODO: Handle stop logic
        echo "SERVICE_NOT_IMPLEMENTED"
        exit 1
        ;;
    status)
        # TODO: Handle status logic
        echo "SERVICE_NOT_IMPLEMENTED"
        exit 1
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
