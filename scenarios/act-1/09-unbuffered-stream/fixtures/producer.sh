#!/usr/bin/env bash
# ==============================================================================
# Security Event Stream Generator (Producer)
# ==============================================================================
# Emits real-time simulated security events spaced at fixed micro-intervals.
# ==============================================================================

set -euo pipefail

EVENT_COUNT=10
INTERVAL=0.02
PREFIX="ALERT"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --count)
            EVENT_COUNT="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

for (( i=1; i<=EVENT_COUNT; i++ )); do
    TIMESTAMP=$(date +%s%N)
    # Write alert event line to stdout
    echo "$PREFIX event_id=$i severity=CRITICAL host=edge-01 time=$TIMESTAMP"
    sleep "$INTERVAL"
done
