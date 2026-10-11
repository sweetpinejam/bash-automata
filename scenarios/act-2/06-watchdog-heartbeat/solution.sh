#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Self-Healing Service Watchdog
# ==============================================================================
set -euo pipefail

PID_FILE="worker.pid"
HEARTBEAT_FILE="heartbeat.ts"
MAX_STALENESS=2

now=$(date +%s)
last_hb=0
if [[ -f "$HEARTBEAT_FILE" ]]; then
  last_hb="$(cat "$HEARTBEAT_FILE")"
fi
staleness=$(( now - last_hb ))

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if kill -0 "$pid" 2>/dev/null; then
    if (( staleness <= MAX_STALENESS )); then
      echo "WATCHDOG: Worker PID $pid is active."
      exit 0
    fi

    # Stale heartbeat detected: kill frozen process
    echo "WATCHDOG: Worker PID $pid is frozen (staleness: ${staleness}s). Escalating kill..."
    kill -TERM "$pid" 2>/dev/null || true
    sleep 0.2
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
fi

echo "WATCHDOG: Worker dead or frozen. Restarting..."
python3 worker_daemon.py >/dev/null 2>&1 &
echo "WORKER_RESPAWNED"
