#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 2.10 (The Graceful Drain Teardown)
# ==============================================================================
# Production Queue Worker implementing two-phase graceful drain with signal
# latching (SIGTERM/SIGINT), safe transaction boundaries, and zero data loss.
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
  "drain_policy": "TWO_PHASE_LATCH"
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
# Signal Latch Configuration
# ------------------------------------------------------------------------------
draining=false

handle_signal() {
    log_warn "SIGTERM/SIGINT signal intercepted! Activating graceful drain latch..."
    draining=true
}

# Install signal trap for termination signals
trap handle_signal TERM INT

# Ensure PID file cleanup on exit
trap 'rm -f "$PID_FILE" 2>/dev/null || true' EXIT

# ------------------------------------------------------------------------------
# Daemon Initialization
# ------------------------------------------------------------------------------
log_info "Initializing transaction consumer worker daemon..."
echo "$$" > "$PID_FILE"

if [[ ! -f "$QUEUE_FILE" ]]; then
    log_error "Queue file '$QUEUE_FILE' not found!"
    exit 1
fi

processed_count=0

log_info "Starting queue processing loop (Source: $QUEUE_FILE)..."

# ------------------------------------------------------------------------------
# Safe Transaction Boundary Processing Loop
# ------------------------------------------------------------------------------
while IFS= read -r job || [[ -n "$job" ]]; do
    [[ -n "$job" ]] || continue

    # Boundary check 1: Refuse new work if drain signal has arrived
    if [[ "$draining" == true ]]; then
        log_info "Drain state active: refusing new queue work ($job)."
        break
    fi

    log_info "Beginning transaction: $job"
    echo "TX_START: $job" >> "$COMMIT_LOG"

    # Simulate database / payment gateway commit latency
    sleep "$TX_DELAY"

    echo "TX_COMMITTED: $job" >> "$COMMIT_LOG"
    log_info "Committed transaction: $job"
    processed_count=$(( processed_count + 1 ))

    # Boundary check 2: Exit loop after completing in-flight transaction
    if [[ "$draining" == true ]]; then
        log_info "Drain state active: cleanly stopping after committed transaction ($job)."
        break
    fi
done < "$QUEUE_FILE"

# ------------------------------------------------------------------------------
# Shutdown & Teardown
# ------------------------------------------------------------------------------
if [[ "$draining" == true ]]; then
    log_info "Recording drain completion in $DRAIN_LOG..."
    echo "DRAIN_COMPLETED" > "$DRAIN_LOG"
    write_telemetry "DRAIN_COMPLETED" "$processed_count"
else
    write_telemetry "QUEUE_EXHAUSTED" "$processed_count"
fi

rm -f "$PID_FILE"
log_info "Worker process shutdown cleanly with exit code 0."
exit 0
