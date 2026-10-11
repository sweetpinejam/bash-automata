#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 2.01 (The Token Bucket Semaphore)
# ==============================================================================
# Pure Bash counting semaphore using a POSIX FIFO and file descriptor 3.
# ==============================================================================

set -euo pipefail

QUEUE_FILE="queue.txt"
CONCURRENCY=4
STATUS_FILE="dispatch_status.json"
MOCK_API="mock_api.py"

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
        --concurrency)
            CONCURRENCY="$2"
            shift 2
            ;;
        --api)
            MOCK_API="$2"
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

rm -f "$STATUS_FILE"

log_info "Initializing batch job dispatcher (PID: $$)..."
log_info "Queue source:        $QUEUE_FILE"
log_info "Target concurrency:  $CONCURRENCY"

# ------------------------------------------------------------------------------
# Semaphore Initialization: FIFO + Bidirectional FD 3
# ------------------------------------------------------------------------------
FIFO="/tmp/sem_$$.fifo"
mkfifo "$FIFO"

MAIN_PID=$$
trap 'if [[ "$BASHPID" == "$MAIN_PID" ]]; then rm -f "$FIFO" 2>/dev/null; exec 3>&- 2>/dev/null || true; fi' EXIT INT TERM

# Open FD 3 for bidirectional FIFO communication (prevents EOF on empty reads)
exec 3<>"$FIFO"
# Unlink FIFO node immediately from filesystem namespace (FD preserves inode)
rm -f "$FIFO"

# Pre-seed counting semaphore with exactly $CONCURRENCY tokens
for (( i=0; i<CONCURRENCY; i++ )); do
    echo >&3
done

log_info "Semaphore initialized with $CONCURRENCY worker tokens. Starting dispatch loop..."

# ------------------------------------------------------------------------------
# Bounded Concurrent Dispatch Loop
# ------------------------------------------------------------------------------
while IFS= read -r item || [[ -n "$item" ]]; do
    [[ -n "$item" ]] || continue

    # Acquire token: blocks if all slots are occupied
    read -u 3

    (
        # Execute worker workload
        python3 "$MOCK_API" "$item"
        # Release token back to pool upon completion
        echo >&3
    ) &
done < "$QUEUE_FILE"

# Wait for all background worker subshells to finish
wait

# Close semaphore descriptor
exec 3>&-

log_info "All queue items processed successfully within concurrency limits."

cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "COMPLETED",
  "queue_file": "$QUEUE_FILE",
  "concurrency_limit": $CONCURRENCY
}
EOF

echo "DISPATCH_COMPLETE"
