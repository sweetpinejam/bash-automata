#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.09: THE UNBUFFERED STREAM (Live Telemetry Filter Pipeline)
# ==============================================================================
# Production event streaming pipeline filtering incoming log notifications.
#
# CRISIS:
# Downstream consumers experience multi-second latency freezes. When utilities
# like 'grep', 'sed', or 'awk' write to a pipe instead of a terminal, the GNU C
# library (glibc stdio) switches from line-buffering to 4KB block-buffering.
# Events are held in user-space buffers until 4,096 bytes accumulate, delaying
# critical security alerts.
#
# MISSION:
# Configure the pipeline filter to enforce line-buffering so that every alert
# is flushed immediately down the pipe as soon as it arrives.
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
# BROKEN STATE: Standard Block-Buffered Pipeline
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# Standard 'grep' writing to a file or pipe detects non-TTY output (isatty == 0)
# and switches libc buffering mode to _IOFBF (4KB block buffering).
# Events remain trapped in stdio memory until the buffer fills!
#
# TODO: Force line buffering on grep using '--line-buffered' or 'stdbuf -oL'.

log_info "Streaming events through pipeline filter..."

bash "$PRODUCER_SCRIPT" | grep "$PATTERN" > "$OUTPUT_FILE"

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
