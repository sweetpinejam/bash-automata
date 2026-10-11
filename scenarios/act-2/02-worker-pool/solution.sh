#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 2.02 (The Runaway Worker Pool)
# ==============================================================================
# Worker pool supervisor with dynamic slot replenishment using wait -n.
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
# Dynamic Slot Replenishment Dispatch Loop
# ------------------------------------------------------------------------------
log_info "Processing queued tasks with dynamic slot replenishment..."

while IFS= read -r task || [[ -n "$task" ]]; do
    [[ -n "$task" ]] || continue

    python3 worker.py "$task" &
    active=$(( active + 1 ))

    # Dynamic slot replenishment: wait for ANY single worker to complete
    if (( active >= MAX_WORKERS )); then
        wait -n
        active=$(( active - 1 ))
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
