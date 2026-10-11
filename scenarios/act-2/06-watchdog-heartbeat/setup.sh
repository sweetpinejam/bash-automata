#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

# Clean prior run
rm -f "$WORKSPACE"/worker.pid "$WORKSPACE"/heartbeat.ts

chmod +x "$WORKSPACE/watchdog.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/worker_daemon.py" 2>/dev/null || true

# Start frozen daemon
(
  cd "$WORKSPACE"
  TRIGGER_FREEZE=true python3 worker_daemon.py >/dev/null 2>&1 &
  sleep 0.2
)

# Overwrite heartbeat with stale timestamp (10 seconds ago)
old_ts=$(( $(date +%s) - 10 ))
echo "$old_ts" > "$WORKSPACE/heartbeat.ts"

echo "[SETUP COMPLETE] Initialized frozen worker with stale heartbeat."
