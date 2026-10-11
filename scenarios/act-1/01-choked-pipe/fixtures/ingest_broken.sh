#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.01: THE CHOKED PIPE (Telemetry Ingest Forwarder Daemon)
# ==============================================================================
# Enterprise log and metric forwarder daemon.
#
# CRISIS:
# Under high-frequency burst traffic (10,000+ metrics/sec), the direct synchronous
# pipe between Bash and Python saturates the 64KB kernel buffer, causing upstream
# stalls, latency spikes, and packet loss.
#
# MISSION:
# Decouple stream ingestion using an asynchronous named pipe (mkfifo), bind a
# defensive cleanup trap across EXIT, INT, and TERM, spawn the Python consumer in
# the background, stream incoming data into the FIFO, and wait for completion.
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

log_info "Initializing telemetry forwarder daemon (PID: $$)..."

# ------------------------------------------------------------------------------
# BROKEN STARTER PIPELINE: Synchronous Anonymous Pipe
# ------------------------------------------------------------------------------
# 💥 VULNERABILITY:
# A synchronous pipe ('cat | python3 process.py') shares a 64KB kernel buffer.
# When python pauses or runs garbage collection, the kernel blocks the producer's
# write() calls, stalling the upstream pipeline.
#
# TODO: Refactor using a decoupled Named Pipe (FIFO):
# 1. Register cleanup trap BEFORE creating the FIFO:
#    trap 'rm -f "$FIFO_PATH"' EXIT INT TERM
# 2. Allocate the named pipe using 'mkfifo "$FIFO_PATH"'
# 3. Launch python3 process.py in the BACKGROUND reading from the FIFO:
#    python3 process.py < "$FIFO_PATH" &
#    CONSUMER_PID=$!
# 4. Stream incoming stdin directly into the FIFO:
#    cat > "$FIFO_PATH"
# 5. Wait for the background consumer to finish:
#    wait "$CONSUMER_PID"

cat | python3 process.py

log_info "Telemetry forwarding cycle finished."
