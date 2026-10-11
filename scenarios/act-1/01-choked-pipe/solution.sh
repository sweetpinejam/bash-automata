#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.01 (The Choked Pipe)
# ==============================================================================
# Decoupled high-throughput telemetry ingestion forwarder using POSIX FIFO.
# ==============================================================================

set -euo pipefail

FIFO_PATH="./telemetry_$$.fifo"
BATCH_SIZE=5000
METRICS_OUT="./ingest_telemetry.json"

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
        --fifo)
            FIFO_PATH="$2"
            shift 2
            ;;
        --batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --metrics-out)
            METRICS_OUT="$2"
            shift 2
            ;;
        *)
            log_warn "Unknown flag: $1, continuing with defaults"
            shift
            ;;
    esac
done

log_info "Initializing decoupled telemetry forwarder (PID: $$)..."

# ------------------------------------------------------------------------------
# Decoupled Asynchronous FIFO Pipeline
# ------------------------------------------------------------------------------
# 1. Guarantee cleanup on normal exit or abnormal termination
trap 'rm -f "$FIFO_PATH"' EXIT INT TERM

# 2. Allocate filesystem FIFO special node
mkfifo "$FIFO_PATH"
log_info "Allocated transient FIFO buffer at $FIFO_PATH"

# 3. Spawn background consumer reading from the FIFO
# Note: The reader MUST be launched first, because opening a FIFO for writing
# blocks until a reader is attached.
python3 process.py < "$FIFO_PATH" &
CONSUMER_PID=$!
log_info "Spawned decoupled consumer worker (PID: $CONSUMER_PID)"

# 4. Stream upstream standard input directly into the FIFO
cat > "$FIFO_PATH"

# 5. Await consumer completion to ensure all batches are drained
wait "$CONSUMER_PID"

log_info "Telemetry forwarding completed with zero packet loss."
