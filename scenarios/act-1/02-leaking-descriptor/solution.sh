#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.02 (The Leaking Descriptor)
# ==============================================================================
# Robust file descriptor lifecycle management preventing EMFILE table leaks.
# ==============================================================================

set -euo pipefail

CYCLES=50
STATUS_FILE="node.status"
SUMMARY_FILE="monitor.summary"

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
        --cycles)
            CYCLES="$2"
            shift 2
            ;;
        --status-file)
            STATUS_FILE="$2"
            shift 2
            ;;
        --summary)
            SUMMARY_FILE="$2"
            shift 2
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                CYCLES="$1"
                shift
            else
                log_warn "Unknown argument: $1, continuing..."
                shift
            fi
            ;;
    esac
done

rm -f "$SUMMARY_FILE"
log_info "Starting health polling daemon for $CYCLES cycles (PID: $$)..."

# ------------------------------------------------------------------------------
# Polling Loop with Defensively Managed File Descriptors
# ------------------------------------------------------------------------------
for (( cycle=1; cycle<=CYCLES; cycle++ )); do
    # Simulate hardware status emission
    echo "health=OK cycle=$cycle load=0.12 memory_mb=$(( 40 + cycle % 10 ))" > "$STATUS_FILE"

    # Allocate dynamic file descriptor
    exec {fd}< "$STATUS_FILE"

    # Read from the dedicated descriptor
    read -r line <&"$fd"
    echo "Cycle $cycle: $line" >> "$SUMMARY_FILE"

    # Defensively close the descriptor immediately after use
    exec {fd}<&-
done

log_info "Completed $CYCLES polling cycles successfully."
echo "MONITOR_RUN_COMPLETE"
