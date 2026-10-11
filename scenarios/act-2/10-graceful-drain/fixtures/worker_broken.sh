#!/usr/bin/env bash
# ==============================================================================
# Transaction Queue Worker (Production Subsystem Wrapper)
# ==============================================================================
# Incident: INCIDENT-2049
# Rolling updates and pod evictions send SIGTERM to container workloads.
# Without a signal drain handler, this worker terminates instantly mid-flight,
# severing active database transactions and leaving corrupted half-committed state.
#
# BROKEN STATE:
# No SIGTERM/SIGINT signal trap or drain latching implemented.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration Defaults
# ------------------------------------------------------------------------------
QUEUE_FILE="jobs.queue"
COMMIT_LOG="transactions.commit"
DRAIN_LOG="drain.log"
PID_FILE="worker.pid"
STATUS_FILE="worker_status.json"
TX_DELAY=0.1
VERBOSE=0

# ------------------------------------------------------------------------------
# Logging Utilities
# ------------------------------------------------------------------------------
log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] [PID:$$] $*" >&2
}

log_warn() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] [PID:$$] $*" >&2
}

log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [ERROR] [PID:$$] $*" >&2
}

# ------------------------------------------------------------------------------
# Telemetry Manifest
# ------------------------------------------------------------------------------
write_telemetry() {
    local status="$1"
    local completed="$2"

    cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "pid": $$,
  "jobs_processed": $completed,
  "status": "$status",
  "drain_policy": "NONE"
}
EOF
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
        --commit-log)
            COMMIT_LOG="$2"
            shift 2
            ;;
        --drain-log)
            DRAIN_LOG="$2"
            shift 2
            ;;
        --pid-file)
            PID_FILE="$2"
            shift 2
            ;;
        --delay)
            TX_DELAY="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--queue PATH] [--commit-log PATH] [--drain-log PATH] [--delay SEC]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Initialization
# ------------------------------------------------------------------------------
log_info "Initializing transaction consumer worker daemon..."
echo "$$" > "$PID_FILE"

if [[ ! -f "$QUEUE_FILE" ]]; then
    log_error "Queue file '$QUEUE_FILE' not found!"
    exit 1
fi

processed_count=0

# ==============================================================================
# BUG: Unprotected transaction consumption loop!
# When SIGTERM arrives from the container orchestrator, Bash aborts immediately.
# Any transaction between TX_START and TX_COMMITTED is severed and corrupted.
# TODO: Install trap for SIGTERM/SIGINT with a signal latch.
# ==============================================================================
log_info "Starting queue processing loop (Source: $QUEUE_FILE)..."

while IFS= read -r job || [[ -n "$job" ]]; do
    [[ -n "$job" ]] || continue

    log_info "Beginning transaction: $job"
    echo "TX_START: $job" >> "$COMMIT_LOG"

    # Simulate database / payment gateway commit latency
    sleep "$TX_DELAY"

    echo "TX_COMMITTED: $job" >> "$COMMIT_LOG"
    log_info "Committed transaction: $job"
    processed_count=$(( processed_count + 1 ))
done < "$QUEUE_FILE"

rm -f "$PID_FILE"
write_telemetry "QUEUE_EXHAUSTED" "$processed_count"
log_info "Queue processing completed successfully ($processed_count jobs)."
exit 0
