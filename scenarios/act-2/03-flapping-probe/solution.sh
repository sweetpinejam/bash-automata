#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 2.03 (The Flaking Healthcheck Latch)
# ==============================================================================
# Canary health probe with consecutive failure threshold latch.
# ==============================================================================

set -euo pipefail

CYCLES=10
FAIL_THRESHOLD=3
INTERVAL=0.01
ENDPOINT_CMD="health_endpoint.py"
STATUS_FILE="canary_status.json"
consecutive_fails=0

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
        --cycles)
            CYCLES="$2"
            shift 2
            ;;
        --threshold)
            FAIL_THRESHOLD="$2"
            shift 2
            ;;
        --endpoint)
            ENDPOINT_CMD="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

rm -f "$STATUS_FILE"

log_info "Initializing canary health probe (PID: $$)..."
log_info "Target probe cycles:     $CYCLES"
log_info "Consecutive threshold:   $FAIL_THRESHOLD"
log_info "Health endpoint command: $ENDPOINT_CMD"

# ------------------------------------------------------------------------------
# Resilient Probe Verification Sequence
# ------------------------------------------------------------------------------
log_info "Beginning canary verification sequence..."

for (( i=1; i<=CYCLES; i++ )); do
    if python3 "$ENDPOINT_CMD"; then
        # Reset failure streak on any successful probe
        consecutive_fails=0
    else
        # Increment consecutive failure count
        consecutive_fails=$(( consecutive_fails + 1 ))
        log_warn "Cycle $i failed! Consecutive failure count: $consecutive_fails/$FAIL_THRESHOLD"

        if (( consecutive_fails >= FAIL_THRESHOLD )); then
            log_error "Persistent service outage detected: threshold of $FAIL_THRESHOLD consecutive failures reached on cycle $i."
            echo "CANARY_ABORTED: Threshold of $FAIL_THRESHOLD consecutive failures reached on cycle $i" >&2
            exit 1
        fi
    fi
    sleep "$INTERVAL"
done

log_info "Canary verification passed all $CYCLES cycles successfully."

cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "HEALTHY",
  "cycles_completed": $CYCLES
}
EOF

echo "CANARY_HEALTHY"
exit 0
