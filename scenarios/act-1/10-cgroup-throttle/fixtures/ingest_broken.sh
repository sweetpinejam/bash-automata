#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.10: THE KERNEL CGROUP THROTTLE (High-Volume Ingestion Daemon)
# ==============================================================================
# Production telemetry event ingestion daemon processing high-volume feeds.
#
# CRISIS:
# When executing inside a resource-constrained container (cgroup memory ceiling
# of 32MB), the ingestion script is abruptly killed by the Linux kernel OOM
# (Out-of-Memory) killer. The script buffers every incoming record into an
# in-memory shell array ('declare -a records'), causing memory usage to spike
# beyond the allowed cgroup quota.
#
# MISSION:
# Refactor 'ingest.sh' to stream records directly from the input feed to the
# output log with O(1) constant memory complexity, keeping peak RSS memory
# strictly below 15MB.
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
# BROKEN STATE: In-Memory Array Buffering (O(N) Memory Bloat)
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# Buffering an unbounded stream into a Bash array ('records+=("$line")')
# dynamically expands the heap. Under a 32MB cgroup limit, Bash memory
# overhead triggers the kernel OOM killer (SIGKILL), losing all data!
#
# TODO: Replace array accumulation with constant-memory O(1) stream redirection:
# while IFS= read -r line; do
#     echo "$RECORD_PREFIX: $line"
# done < "$INPUT_FILE" > "$OUTPUT_FILE"

declare -a records
log_info "Buffering incoming records into memory array..."

while IFS= read -r line; do
    records+=("$line")
done < "$INPUT_FILE"

log_info "Writing buffered records to disk..."
for item in "${records[@]}"; do
    echo "$RECORD_PREFIX: $item" >> "$OUTPUT_FILE"
done

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
