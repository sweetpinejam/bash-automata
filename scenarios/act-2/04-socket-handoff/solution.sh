#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Unix Domain Socket Service Controller
# ==============================================================================
set -euo pipefail

PID_FILE="daemon.pid"
SOCKET_FILE="daemon.sock"

stop() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    kill -TERM "$pid" 2>/dev/null || true
    for (( i=0; i<20; i++ )); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.05
    done
    rm -f "$PID_FILE"
  fi
  rm -f "$SOCKET_FILE"
  echo "SERVICE_STOPPED"
}

start() {
  # Clean lingering or stale socket
  rm -f "$SOCKET_FILE"

  python3 daemon.py >/dev/null 2>&1 &
  local new_pid=$!
  echo "$new_pid" > "$PID_FILE"

  # Readiness wait loop
  local ready=false
  for (( i=0; i<40; i++ )); do
    if [[ -S "$SOCKET_FILE" ]] && python3 client.py >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 0.05
  done

  if ! $ready; then
    echo "ERROR: Failed to establish active socket" >&2
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
