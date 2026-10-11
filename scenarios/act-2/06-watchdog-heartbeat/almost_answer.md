# Structural Scaffolding: Watchdog Heartbeat Staleness & Process Escalation

To detect and recover from silent application deadlocks without relying solely on `kill -0`, calculate heartbeat pulse staleness and escalate signal termination:

---

## Pattern: Heartbeat Watchdog with Signal Escalation

```bash
PID_FILE="worker.pid"
HEARTBEAT_FILE="heartbeat.ts"
MAX_STALENESS=2

# 1. Compute staleness using epoch arithmetic:
now=$(date +%s)
last_hb=0
[[ -f "$HEARTBEAT_FILE" ]] && last_hb="$(cat "$HEARTBEAT_FILE")"
staleness=$(( now - last_hb ))

# 2. Check active worker process state:
if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
        if (( staleness <= MAX_STALENESS )); then
            echo "WATCHDOG: Worker PID $pid is active."
            exit 0
        fi

        # Process is alive but deadlocked: Escalate termination
        echo "WATCHDOG: Worker PID $pid is frozen! Terminating..."
        kill -TERM "$pid" 2>/dev/null || true

        # Grace period before force kill:
        sleep 0.2
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
fi

# 3. Self-healing respawn:
echo "WATCHDOG: Worker dead or frozen. Restarting..."
python3 worker_daemon.py >/dev/null 2>&1 &
echo "WORKER_RESPAWNED"
```

---

## Verifying Recovery

Inspect heartbeat advance after watchdog execution:
```bash
# Check timestamp updates:
watch -n 0.1 'cat heartbeat.ts'
```
The timestamp in `heartbeat.ts` should advance continuously under the newly spawned worker instance.
