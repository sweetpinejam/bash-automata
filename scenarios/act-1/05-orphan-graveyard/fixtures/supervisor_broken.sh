#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.05: THE ORPHAN GRAVEYARD (Batch Worker Supervisor Daemon)
# ==============================================================================
# Production batch processing supervisor that dispatches worker jobs in parallel.
#
# CRISIS:
# The supervisor spawns dozens of background tasks. When workers finish and exit,
# the supervisor fails to call 'wait'. Terminated workers remain trapped in state
# 'Z' (Zombie / defunct), rapidly consuming PID slots toward 'pid_max' exhaustion.
#
# MISSION:
# Reclaim all child processes: call 'wait' to reap terminated children from the
# process table before the supervisor finishes execution.
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
        # Simulate worker processing
        sleep 0.05
        echo "TASK_$i: DONE" >> "$DONE_FILE"
        exit 0
    ) &
done

log_info "Dispatched $TOTAL_TASKS background workers. Waiting for completion..."

# ------------------------------------------------------------------------------
# BROKEN STATE: Missing Process Reaping
# ------------------------------------------------------------------------------
# 💥 THE ZOMBIE BUG:
# When background children exit, the Linux kernel holds their exit records in the
# process table until the parent reads them via wait().
# Because the supervisor sleeps without calling 'wait', 20 zombie processes ([defunct])
# leak in the process table!
#
# TODO: Reap all background child worker processes:
# wait

sleep 0.5

log_info "All batch tasks completed."
echo "SUPERVISOR_DONE"
