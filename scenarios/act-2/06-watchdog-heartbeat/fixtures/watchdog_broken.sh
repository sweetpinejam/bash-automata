#!/usr/bin/env bash
# ==============================================================================
# Self-Healing Service Watchdog
# Incident: The worker daemon silently freezes its event loop. Because the PID
# is still alive in the process table (kill -0 passes), this naive watchdog
# assumes the service is healthy while metrics pipeline sits frozen!
# Target: Inspect heartbeat.ts timestamp staleness. If older than 2 seconds,
# execute self-healing: terminate the frozen PID (escalating to kill -9 if needed)
# and respawn a healthy worker daemon.
# ==============================================================================
set -euo pipefail

PID_FILE="worker.pid"
HEARTBEAT_FILE="heartbeat.ts"
MAX_STALENESS=2

# BROKEN / NAIVE PID CHECK:
# Only checks if PID exists. Never detects internal event loop lockups!
if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "WATCHDOG: Worker PID $pid is active."
    exit 0
  fi
fi

echo "WATCHDOG: Worker dead. Restarting..."
python3 worker_daemon.py >/dev/null 2>&1 &
echo "WORKER_RESPAWNED"
