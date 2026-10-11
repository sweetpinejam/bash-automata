#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 2.01: THE TOKEN BUCKET SEMAPHORE (Batch API Dispatcher)
# ==============================================================================
# Production batch ingestion dispatcher that forwards work items to an API.
#
# CRISIS:
# INCIDENT-4290: The dispatcher reads 16 jobs from 'queue.txt' and spawns all of
# them into background subshells simultaneously without any concurrency bounds.
# The sudden burst of parallel connections overwhelms the upstream API gateway,
# triggering HTTP 429 (Too Many Requests) rate-limiting blocks!
#
# MISSION:
# Implement a pure Bash counting semaphore using a POSIX named pipe (FIFO) and a
# dedicated file descriptor (FD 3) to strictly bound background concurrency to
# at most 4 active worker subshells at any point in time.
#
# CONSTRAINTS:
# - Zero external dependencies (NO 'xargs -P', NO 'parallel').
# - Zero serialization (must execute concurrently up to the 4-worker limit).
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
# BROKEN STATE: Unbounded Subshell Burst
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# Every item in the queue is spawned into the background immediately with '&'.
# Without a counting semaphore to block the loop, all 16 jobs execute concurrently,
# triggering HTTP 429 rate limit bans in the upstream mock API!
#
# TODO:
# 1. Create a named pipe (FIFO) and bind it to FD 3 with 'exec 3<>"$FIFO"'.
# 2. Pre-populate the FIFO with $CONCURRENCY tokens (echo >&3).
# 3. Acquire a token before launching each worker: 'read -u 3'.
# 4. Release the token inside the worker subshell upon exit: '( ...; echo >&3 ) &'.

log_info "Dispatching workload to upstream API..."

while IFS= read -r item || [[ -n "$item" ]]; do
    [[ -n "$item" ]] || continue

    (
        python3 "$MOCK_API" "$item"
    ) &
done < "$QUEUE_FILE"

# Wait for all background worker subshells to finish
wait

log_info "All queue items processed."

cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "COMPLETED",
  "queue_file": "$QUEUE_FILE"
}
EOF

echo "DISPATCH_COMPLETE"
