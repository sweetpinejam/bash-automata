#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.07 (The Shared Memory Bus)
# ==============================================================================
# High-frequency telemetry writer streaming via Linux tmpfs (/dev/shm).
# ==============================================================================

set -euo pipefail

TOTAL_FRAMES=100
INTERVAL=0.005
BUS_FILE="/dev/shm/telemetry_bus.dat"

log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] $*" >&2
}

log_warn() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] $*" >&2
}

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --frames)
            TOTAL_FRAMES="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --bus)
            BUS_FILE="$2"
            shift 2
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                TOTAL_FRAMES="$1"
                shift
            else
                shift
            fi
            ;;
    esac
done

log_info "Initializing telemetry emitter (PID: $$)..."
log_info "Target metrics buffer: $BUS_FILE"
log_info "Target frame count:    $TOTAL_FRAMES"

# ------------------------------------------------------------------------------
# Defensive Resource Reclamation: Trap Unlink in Kernel tmpfs
# ------------------------------------------------------------------------------
MAIN_PID=$$
trap 'if [[ "$BASHPID" == "$MAIN_PID" ]]; then rm -f "$BUS_FILE"; fi' EXIT INT TERM

# ------------------------------------------------------------------------------
# High-Frequency Emission Loop via /dev/shm
# ------------------------------------------------------------------------------
for (( i=1; i<=TOTAL_FRAMES; i++ )); do
    LOAD_VAL=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0.15")
    UPTIME_VAL=$(awk '{print $1}' /proc/uptime 2>/dev/null || echo "1234.5")

    echo "FRAME_$i load=$LOAD_VAL uptime=$UPTIME_VAL temp=42C" > "$BUS_FILE"
    sleep "$INTERVAL"
done

log_info "Completed streaming $TOTAL_FRAMES telemetry frames."
echo "WRITER_FINISHED"
