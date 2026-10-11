#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 2.06 (The Self-Healing Watchdog Heartbeat)
# ==============================================================================
# Self-healing watchdog monitoring heartbeat staleness with signal escalation.
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
# Heartbeat Staleness Calculation
# ------------------------------------------------------------------------------
now=$(date +%s)
last_hb=0
if [[ -f "$HEARTBEAT_FILE" ]]; then
    last_hb="$(cat "$HEARTBEAT_FILE")"
fi
staleness=$(( now - last_hb ))

log_info "Current timestamp: $now, Last heartbeat: $last_hb (Staleness: ${staleness}s)"

# ------------------------------------------------------------------------------
# Process Inspection & Signal Escalation
# ------------------------------------------------------------------------------
if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
        if (( staleness <= MAX_STALENESS )); then
            log_info "Worker PID $pid is healthy (staleness: ${staleness}s <= ${MAX_STALENESS}s)."
            echo "WATCHDOG: Worker PID $pid is active."
            exit 0
        fi

        log_warn "Worker PID $pid is frozen in silent deadlock (staleness: ${staleness}s > ${MAX_STALENESS}s)! Escalating termination..."
        echo "WATCHDOG: Worker PID $pid is frozen (staleness: ${staleness}s). Escalating kill..."

        # Stage 1: Graceful SIGTERM
        kill -TERM "$pid" 2>/dev/null || true
        sleep 0.2

        # Stage 2: Force eviction via SIGKILL
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
fi

# ------------------------------------------------------------------------------
# Self-Healing Respawn
# ------------------------------------------------------------------------------
log_info "Worker dead or frozen. Respawning fresh daemon instance..."
echo "WATCHDOG: Worker dead or frozen. Restarting..."

python3 "$DAEMON_CMD" >/dev/null 2>&1 &

cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "RECOVERED",
  "staleness_observed": $staleness
}
EOF

echo "WORKER_RESPAWNED"
