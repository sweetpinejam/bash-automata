#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.05 (The Orphan Graveyard)
# ==============================================================================
# Batch supervisor with active child process reaping via wait.
# ==============================================================================

set -euo pipefail

TOTAL_TASKS=20
DONE_FILE="batch.done"
LOG_FILE="supervisor.log"

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
        --tasks)
            TOTAL_TASKS="$2"
            shift 2
            ;;
        --output)
            DONE_FILE="$2"
            shift 2
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                TOTAL_TASKS="$1"
                shift
            else
                shift
            fi
            ;;
    esac
done

rm -f "$DONE_FILE" "$LOG_FILE"
log_info "Initializing batch supervisor (PID: $$) for $TOTAL_TASKS tasks..."

# ------------------------------------------------------------------------------
# Dispatch Background Worker Tasks
# ------------------------------------------------------------------------------
for (( i=1; i<=TOTAL_TASKS; i++ )); do
    (
        sleep 0.05
        echo "TASK_$i: DONE" >> "$DONE_FILE"
        exit 0
    ) &
done

log_info "Dispatched $TOTAL_TASKS background workers. Reaping children..."

# Actively reap all background child processes to prevent zombie table leaks
wait

log_info "All batch tasks completed."
echo "SUPERVISOR_DONE"
