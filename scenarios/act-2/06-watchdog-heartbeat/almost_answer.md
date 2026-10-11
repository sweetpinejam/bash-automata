# Code Blueprint: Watchdog Heartbeat Staleness & Process Escalation

Detect silently frozen daemons using timestamp math and escalate signal termination:

```bash
# Blueprint Pattern:
PID_FILE="worker.pid"
HEARTBEAT_FILE="heartbeat.ts"
MAX_STALENESS=2

now=$(date +%s)
last_hb=0
[[ -f "$HEARTBEAT_FILE" ]] && last_hb="$(cat "$HEARTBEAT_FILE")"
staleness=$(( now - last_hb ))

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  pid="$(cat "$PID_FILE")"
  if (( staleness <= MAX_STALENESS )); then
    echo "WATCHDOG: Worker PID $pid is healthy (staleness: ${staleness}s)."
    exit 0
  fi

  echo "WATCHDOG: Worker PID $pid is frozen (staleness: ${staleness}s)! Killing..."
  kill -TERM "$pid" 2>/dev/null || true
  # Give 0.2s for graceful exit; escalate to SIGKILL if still hung:
  sleep 0.2
  kill -9 "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"
fi

echo "WATCHDOG: Respawning worker daemon..."
python3 worker_daemon.py >/dev/null 2>&1 &
echo "WORKER_RESPAWNED"
```

> **Key Rule**: Never rely solely on `kill -0` for healthchecks. A deadlocked process remains in the OS process table forever. Check active pulse timestamps (`$(( $(date +%s) - last_heartbeat ))`).
