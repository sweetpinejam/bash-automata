#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 2.06: THE SELF-HEALING WATCHDOG HEARTBEAT (Daemon Supervisor)
# ==============================================================================
# Production self-healing supervisor monitoring critical background worker daemons.
#
# CRISIS:
# INCIDENT-7119: Telemetry ingest pipelines have halted across all nodes. The worker
# daemon has deadlocked internally, freezing its event loop. Because the process is
# still alive in the Linux process table (kill -0 passes), this naive watchdog
# assumes the service is healthy while no actual work is being performed!
#
# MISSION:
# Harden 'watchdog.sh' to inspect timestamp staleness in 'heartbeat.ts'.
# If the pulse is older than 2 seconds, terminate the frozen process (escalating
# from SIGTERM to SIGKILL if necessary), clear the PID file, and respawn a
# healthy worker daemon.
# ==============================================================================

set -euo pipefail

PID_FILE="worker.pid"
HEARTBEAT_FILE="heartbeat.ts"
MAX_STALENESS=2
DAEMON_CMD="worker_daemon.py"
STATUS_FILE="watchdog_status.json"

log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] $*" >&2
}

log_warn() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] $*" >&2
}

log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [ERROR] $*" >&2
}

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pidfile)
            PID_FILE="$2"
            shift 2
            ;;
        --heartbeat)
            HEARTBEAT_FILE="$2"
            shift 2
            ;;
        --staleness)
            MAX_STALENESS="$2"
            shift 2
            ;;
        --daemon)
            DAEMON_CMD="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

rm -f "$STATUS_FILE"

log_info "Initializing service watchdog (PID: $$)..."
log_info "Monitoring PID file:      $PID_FILE"
log_info "Monitoring heartbeat:     $HEARTBEAT_FILE"
log_info "Maximum allowed staleness: ${MAX_STALENESS}s"

# ------------------------------------------------------------------------------
# BROKEN STATE: Naive Process Table Liveness Check
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# The watchdog only checks if the PID exists via 'kill -0'.
# A deadlocked or wedged worker process remains in the OS process table indefinitely,
# completely deceiving this naive health check!
#
# TODO:
# 1. Read timestamp from $HEARTBEAT_FILE and calculate staleness:
#    staleness=$(( $(date +%s) - last_hb ))
# 2. If process is alive but staleness > MAX_STALENESS:
#    - Send SIGTERM, wait 0.2s, escalate to SIGKILL (kill -9)
#    - Remove $PID_FILE
# 3. If process is dead or was killed:
#    - Respawn via 'python3 "$DAEMON_CMD" >/dev/null 2>&1 &'
#    - Emit 'WORKER_RESPAWNED'

if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
        log_info "Process table reports PID $pid is alive. Assuming healthy."
        echo "WATCHDOG: Worker PID $pid is active."
        exit 0
    fi
fi

log_warn "Worker PID missing from process table. Respawning..."
python3 "$DAEMON_CMD" >/dev/null 2>&1 &
echo "WORKER_RESPAWNED"
