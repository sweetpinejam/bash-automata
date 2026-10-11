#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.10 (The Kernel Cgroup Throttle)
# ==============================================================================
# Ingestion collector with constant O(1) memory streaming.
# ==============================================================================

set -euo pipefail

INPUT_FILE="feed.raw"
OUTPUT_FILE="processed.log"
STATUS_FILE="ingest_status.json"
RECORD_PREFIX="PROCESSED"

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
        --input)
            INPUT_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --prefix)
            RECORD_PREFIX="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ ! -f "$INPUT_FILE" ]]; then
    log_error "Input feed '$INPUT_FILE' does not exist!"
    exit 1
fi

rm -f "$OUTPUT_FILE" "$STATUS_FILE"

log_info "Initializing event ingestion daemon (PID: $$)..."
log_info "Input feed:  $INPUT_FILE"
log_info "Output log:  $OUTPUT_FILE"

# ------------------------------------------------------------------------------
# CONSTANT O(1) MEMORY STREAMING
# ------------------------------------------------------------------------------
log_info "Streaming records directly from input feed to output log..."

# Streaming line-by-line keeps process memory strictly constant (< 5MB RSS)
while IFS= read -r line; do
    echo "$RECORD_PREFIX: $line"
done < "$INPUT_FILE" > "$OUTPUT_FILE"

# ------------------------------------------------------------------------------
# Ingestion Telemetry Manifest
# ------------------------------------------------------------------------------
TOTAL_PROCESSED=$(wc -l < "$OUTPUT_FILE" 2>/dev/null || echo "0")
log_info "Ingestion complete. Processed $TOTAL_PROCESSED records."

cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "COMPLETED",
  "records_ingested": $TOTAL_PROCESSED
}
EOF

echo "INGEST_FINISHED"
