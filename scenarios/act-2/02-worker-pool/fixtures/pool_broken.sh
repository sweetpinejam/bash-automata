#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 2.02: THE RUNAWAY WORKER POOL (Dynamic Worker Pool Supervisor)
# ==============================================================================
# Production batch processing supervisor executing queued tasks with bounded concurrency.
#
# CRISIS:
# INCIDENT-8120: Overall batch pipeline throughput has collapsed by 65%. Profiling
# reveals that worker slots sit completely idle because the supervisor uses
# lockstep batching: it waits for ALL active workers to finish before scheduling
# the next set of jobs. If one task is slow, fast worker slots remain idle!
#
# MISSION:
# Refactor 'pool_manager.sh' to use dynamic slot replenishment with 'wait -n'
# (Bash 4.3+): replenish capacity immediately whenever ANY single child worker
# terminates, maintaining a strict concurrency clamp of 3 active workers.
# ==============================================================================

set -euo pipefail

QUEUE_FILE="incoming.queue"
MAX_WORKERS=3
LOG_FILE="processed.log"
STATUS_FILE="pool_status.json"
active=0

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
        --queue)
            QUEUE_FILE="$2"
            shift 2
            ;;
        --workers)
            MAX_WORKERS="$2"
            shift 2
            ;;
        --output)
            LOG_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ ! -f "$QUEUE_FILE" ]]; then
    log_error "Queue file '$QUEUE_FILE' not found!"
    exit 1
fi

rm -f "$LOG_FILE" "$STATUS_FILE"

log_info "Initializing worker pool manager (PID: $$)..."
log_info "Queue source:        $QUEUE_FILE"
log_info "Worker pool clamp:   $MAX_WORKERS"

# ------------------------------------------------------------------------------
# BROKEN STATE: Lockstep Batching Barrier
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# The supervisor waits for ALL active workers to terminate with a generic 'wait'.
# If one worker takes longer, all other worker slots sit idle waiting for it.
#
# TODO: Replace the collective 'wait' barrier with dynamic slot replenishment:
# when 'active >= MAX_WORKERS', call 'wait -n' and decrement 'active'.

log_info "Processing queued tasks..."

while IFS= read -r task || [[ -n "$task" ]]; do
    [[ -n "$task" ]] || continue

    python3 worker.py "$task" &
    active=$(( active + 1 ))

    # Lockstep barrier stalls the pipeline:
    if (( active >= MAX_WORKERS )); then
        wait
        active=0
    fi
done < "$QUEUE_FILE"

# Drain any remaining active workers
wait

log_info "Worker pool execution finished. Draining complete."

TOTAL_PROCESSED=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "COMPLETED",
  "tasks_processed": $TOTAL_PROCESSED
}
EOF

echo "POOL_DRAINED"
