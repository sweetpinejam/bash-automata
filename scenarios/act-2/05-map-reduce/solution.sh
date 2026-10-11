#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 2.05 (The Parallel Map-Reduce Stream)
# ==============================================================================
# Parallel Map-Reduce orchestrator with cohort PID tracking and array barrier wait.
# ==============================================================================

set -euo pipefail

PARTITION_PATTERN="part_*.log"
MAPPER_CMD="mapper.sh"
REDUCER_CMD="reducer.py"
STATUS_FILE="orchestration_status.json"

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
        --pattern)
            PARTITION_PATTERN="$2"
            shift 2
            ;;
        --mapper)
            MAPPER_CMD="$2"
            shift 2
            ;;
        --reducer)
            REDUCER_CMD="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

rm -f summary_part_*.tsv final_metrics.json "$STATUS_FILE"

log_info "Initializing Map-Reduce batch orchestrator (PID: $$)..."
log_info "Partition file pattern: $PARTITION_PATTERN"
log_info "Mapper script:          $MAPPER_CMD"
log_info "Reducer script:         $REDUCER_CMD"

# ------------------------------------------------------------------------------
# Parallel Fan-Out with PID Cohort Tracking
# ------------------------------------------------------------------------------
map_pids=()
log_info "Dispatching parallel partition mappers..."

for part in $PARTITION_PATTERN; do
    [[ -f "$part" ]] || continue

    log_info "Spawning mapper for partition: $part"
    bash "$MAPPER_CMD" "$part" &
    map_pids+=("$!")
done

log_info "Dispatched ${#map_pids[@]} mappers. Establishing synchronization barrier..."

# Barrier synchronization: Wait for ALL mappers in the cohort to finish
wait "${map_pids[@]}"

log_info "All partition mappers completed. Intermediate tables synced to disk."

# ------------------------------------------------------------------------------
# Reduction Step
# ------------------------------------------------------------------------------
log_info "Executing final reduction aggregation..."
python3 "$REDUCER_CMD"

log_info "Map-Reduce orchestration complete."

cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "COMPLETED",
  "reducer": "$REDUCER_CMD",
  "mappers_count": ${#map_pids[@]}
}
EOF

echo "ORCHESTRATION_COMPLETE"
