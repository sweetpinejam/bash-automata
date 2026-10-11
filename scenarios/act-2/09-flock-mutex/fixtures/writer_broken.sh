#!/usr/bin/env bash
# ==============================================================================
# Shared Metrics Dump Writer (Production Subsystem Wrapper)
# ==============================================================================
# Incident: INCIDENT-3104
# Multiple parallel cron workers concurrently stream multi-line TSV telemetry
# records into 'metrics_dump.tsv'. Without kernel synchronization, multi-syscall
# writes interleave across process boundaries, causing torn records.
#
# BROKEN STATE:
# Workers append directly without acquiring Linux kernel advisory locks ('flock').
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration Defaults
# ------------------------------------------------------------------------------
WORKER_ID="${1:-worker_1}"
OUTPUT_FILE="metrics_dump.tsv"
LOCK_FILE="metrics.lock"
RECORDS_COUNT=10
SLEEP_INTERVAL=0.005
STATUS_FILE="worker_${WORKER_ID}_status.json"
VERBOSE=0

# ------------------------------------------------------------------------------
# Logging Utilities
# ------------------------------------------------------------------------------
log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] [$WORKER_ID] $*" >&2
}

log_warn() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] [$WORKER_ID] $*" >&2
}

log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [ERROR] [$WORKER_ID] $*" >&2
}

# ------------------------------------------------------------------------------
# Telemetry Manifest
# ------------------------------------------------------------------------------
write_telemetry() {
    local status="$1"
    local written="$2"

    cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "worker_id": "$WORKER_ID",
  "records_written": $written,
  "status": "$status",
  "lock_mechanism": "NONE"
}
EOF
}

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --worker-id)
            WORKER_ID="$2"
            shift 2
            ;;
        --records)
            RECORDS_COUNT="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --lock-file)
            LOCK_FILE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        worker_*)
            WORKER_ID="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [worker_id] [--records N] [--output PATH] [--lock-file PATH]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Worker Execution
# ------------------------------------------------------------------------------
log_info "Starting telemetry batch write (Target: $OUTPUT_FILE, Records: $RECORDS_COUNT)..."

# ==============================================================================
# BUG: Unprotected concurrent append loop!
# Multiple kernel write() syscalls per record interleave with competing workers.
# TODO: Acquire exclusive advisory lock ('flock -x') on a dedicated descriptor.
# ==============================================================================
for (( i=1; i<=RECORDS_COUNT; i++ )); do
    log_info "Writing record $i/$RECORDS_COUNT (UNLOCKED)..."
    echo "START_ROW" >> "$OUTPUT_FILE"
    sleep "$SLEEP_INTERVAL"
    echo -e "worker=$WORKER_ID\tseq=$i\tdata=payload_$i" >> "$OUTPUT_FILE"
    echo "END_ROW" >> "$OUTPUT_FILE"
done

write_telemetry "COMPLETED_UNPROTECTED" "$RECORDS_COUNT"
log_info "Worker batch complete ($RECORDS_COUNT records written)."
exit 0
