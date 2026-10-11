# Tactical Field Manual: The Self-Healing Watchdog Heartbeat

> **Incident Class**: Silent Thread Deadlock, Heartbeat Staleness & Auto-Recovery  
> **Key Tooling**: Epoch Timestamp Subtraction (`$(( now - last_hb ))`), Process Escalation (`SIGTERM` ➔ `SIGKILL`)

---

## 1. The Incident: The Zombie Alive Illusion

In production Linux monitoring, scripts often rely on process existence:
```bash
if kill -0 "$PID"; then
  echo "OK"
fi
```
However, **a process can be alive in the kernel process table while being completely non-functional**:
- A worker thread deadlocked on an unreleased mutex lock.
- A database query stuck on an un-timed-out socket read.
- An infinite busy-loop consuming 100% CPU without serving work.

To the operating system, the PID is valid. But to users, the service is dead.

---

## 2. Architecture: Heartbeat Pulse & Watchdog Loop

```
  WORKER DAEMON
       │ (Every 50ms)
       ▼
  [heartbeat.ts] ──► Writes Epoch timestamp: $(date +%s)
       ▲
       │
  WATCHDOG CHECK:
  now=$(date +%s)
  staleness=$(( now - last_heartbeat ))
       │
       ├─► staleness <= 2s : [HEALTHY] ──► No action.
       │
       └─► staleness > 2s  : [DEADLOCK DETECTED!]
                                  │
                                  ├─► 1. kill -TERM $pid
                                  ├─► 2. sleep 0.2
                                  ├─► 3. kill -9 $pid (Force reap)
                                  └─► 4. Respawn new worker
```

---

## 3. Pure Bash Timestamp Calculations

Bash arithmetic natively supports basic integer operations without external tools like `bc`:
```bash
now=$(date +%s)
staleness=$(( now - last_hb ))
if (( staleness > MAX_ALLOWED )); then
  # Trigger recovery
fi
```
Combining active pulse checks with escalating signal termination provides self-healing resilience against silent crashes.
