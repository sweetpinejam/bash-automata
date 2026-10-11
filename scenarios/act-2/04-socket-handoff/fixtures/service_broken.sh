#!/usr/bin/env bash
# ==============================================================================
# Unix Domain Socket Service Controller
# Incident: Restarting the service drops client connections and crashes with
# 'Address already in use' because stale sockets are not unlinked and new
# instances are not verified before returning.
# Target: Implement safe restart & readiness probing:
#   1. Gracefully terminate existing daemon (SIGTERM), waiting for it to exit
#   2. Clean up any lingering/stale socket file before launching new instance
#   3. Launch new daemon in background
#   4. Poll socket readiness (up to 2 seconds) before reporting success
# ==============================================================================
set -euo pipefail

PID_FILE="daemon.pid"
SOCKET_FILE="daemon.sock"

start() {
  # BROKEN: Fails if a stale daemon.sock exists on disk!
  python3 daemon.py >/dev/null 2>&1 &
  echo "SERVICE_STARTED"
}

stop() {
  if [[ -f "$PID_FILE" ]]; then
    # BROKEN: kill -9 prevents cleanup handler from running
    kill -9 "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
  echo "SERVICE_STOPPED"
}

restart() {
  # BROKEN: Hard kill leaving stale socket, no readiness wait:
  stop
  start
  echo "RESTART_COMPLETE"
}

status() {
  if [[ -f "$PID_FILE" ]] && [[ -S "$SOCKET_FILE" ]]; then
    echo "STATUS_RUNNING"
  else
    echo "STATUS_STOPPED"
  fi
}

case "${1:-status}" in
  start) start ;;
  stop) stop ;;
  restart) restart ;;
  status) status ;;
  *) echo "Usage: service_ctl.sh {start|stop|restart|status}" >&2; exit 1 ;;
esac
