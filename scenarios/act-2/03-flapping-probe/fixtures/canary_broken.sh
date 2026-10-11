#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 2.03: THE FLAKING HEALTHCHECK LATCH (Canary Health Probe Daemon)
# ==============================================================================
# Automated canary health verifier that monitors new deployment candidates.
#
# CRISIS:
# INCIDENT-9031: 85% of automated canary deployments are rolling back prematurely.
# Analysis reveals that isolated, transient network glitches or microsecond
# GC pauses cause a single probe cycle to return non-zero. The legacy checker
# immediately aborts on the first error, causing false-positive rollbacks!
#
# MISSION:
# Implement a resilient consecutive failure threshold latch: tolerate isolated
# transient blips, but abort with exit code 1 if 3 CONSECUTIVE health checks
# fail. Any successful probe must immediately reset the failure streak to 0.
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
# BROKEN STATE: Zero-Tolerance Flapping Probe
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# The checker aborts deployment on the very first transient non-zero exit code!
# Microservice blips immediately trigger false alarms and abort valid releases.
#
# TODO: Implement a consecutive failure latch:
# if python3 "$ENDPOINT_CMD"; then
#     consecutive_fails=0
# else
#     consecutive_fails=$(( consecutive_fails + 1 ))
#     if (( consecutive_fails >= FAIL_THRESHOLD )); then
#         echo "CANARY_ABORTED: Threshold reached on cycle $i" >&2
#         exit 1
#     fi
# fi

log_info "Beginning canary verification sequence..."

for (( i=1; i<=CYCLES; i++ )); do
    if ! python3 "$ENDPOINT_CMD"; then
        log_error "Probe failed on cycle $i! Aborting canary release..."
        echo "CANARY_ABORTED: Probe failed on cycle $i" >&2
        exit 1
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
