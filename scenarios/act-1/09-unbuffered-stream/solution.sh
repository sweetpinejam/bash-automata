#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.09 (The Unbuffered Stream)
# ==============================================================================
# Real-time event streaming pipeline with line buffering enabled.
# ==============================================================================

set -euo pipefail

PRODUCER_SCRIPT="producer.sh"
OUTPUT_FILE="events.stream"
PATTERN="ALERT"
STATUS_FILE="pipeline_status.json"

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
        --producer)
            PRODUCER_SCRIPT="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --pattern)
            PATTERN="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

rm -f "$OUTPUT_FILE" "$STATUS_FILE"

log_info "Initializing streaming log filter pipeline (PID: $$)..."
log_info "Event producer: $PRODUCER_SCRIPT"
log_info "Target stream:  $OUTPUT_FILE"
log_info "Filter pattern: $PATTERN"

# ------------------------------------------------------------------------------
# LINE-BUFFERED STREAM: Force Immediate Flushing Across Pipe
# ------------------------------------------------------------------------------
log_info "Streaming events through line-buffered pipeline filter..."

# Using --line-buffered forces grep to flush each matched newline immediately
bash "$PRODUCER_SCRIPT" | grep --line-buffered "$PATTERN" > "$OUTPUT_FILE"

# ------------------------------------------------------------------------------
# Post-stream Telemetry
# ------------------------------------------------------------------------------
EVENT_COUNT=$(wc -l < "$OUTPUT_FILE" 2>/dev/null || echo "0")
log_info "Pipeline processing complete. Streamed $EVENT_COUNT events."

cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "COMPLETED",
  "events_processed": $EVENT_COUNT,
  "output_file": "$OUTPUT_FILE"
}
EOF

echo "PIPELINE_COMPLETE"
