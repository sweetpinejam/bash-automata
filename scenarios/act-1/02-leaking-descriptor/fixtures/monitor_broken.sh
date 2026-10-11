#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.02: THE LEAKING DESCRIPTOR (Node Health Monitor Daemon)
# ==============================================================================
# Enterprise node health monitor that periodically queries device status.
#
# CRISIS:
# The monitor daemon dynamically allocates custom file descriptors in a polling
# loop. Because it fails to close the descriptors, entries accumulate in the
# process table until hitting 'ulimit -n' limits, crashing with 'Too many open files'.
#
# MISSION:
# Manage the complete descriptor lifecycle: explicitly close every allocated
# descriptor using 'exec {fd}<&-' before the next polling iteration.
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
# Polling Loop
# ------------------------------------------------------------------------------
for (( cycle=1; cycle<=CYCLES; cycle++ )); do
    # Simulate hardware status emission
    echo "health=OK cycle=$cycle load=0.12 memory_mb=$(( 40 + cycle % 10 ))" > "$STATUS_FILE"

    # Allocate a dynamic file descriptor (Bash assigns an unused FD >= 10)
    exec {fd}< "$STATUS_FILE"

    # Read status payload from custom descriptor
    read -r line <&"$fd"
    echo "Cycle $cycle: $line" >> "$SUMMARY_FILE"

    # 💥 BUG:
    # The allocated descriptor ($fd) is left open in the process table!
    # Under restrictive ulimit -n limits, the table exhausts rapidly.
    #
    # TODO: Close the allocated file descriptor here to recycle the table slot:
    # exec {fd}<&-

done

log_info "Completed $CYCLES polling cycles successfully."
echo "MONITOR_RUN_COMPLETE"
