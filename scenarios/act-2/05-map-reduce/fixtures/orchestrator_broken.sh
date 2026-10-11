#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 2.05: THE PARALLEL MAP-REDUCE STREAM (Analytics Orchestrator)
# ==============================================================================
# Production parallel Map-Reduce batch aggregator.
#
# CRISIS:
# INCIDENT-5510: Analytics metrics are consistently missing 50% to 75% of log data!
# The orchestrator spawns 4 partition mappers concurrently in the background, but
# only tracks the PID of the last mapper. When the last mapper finishes, the
# orchestrator immediately launches the reducer while earlier mappers are still
# writing, dropping their partitions from the final reduction!
#
# MISSION:
# Refactor 'orchestrator.sh' to collect all mapper background PIDs into a Bash
# array and establish an explicit barrier wait across the full cohort before
# invoking the reducer.
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
# BROKEN STATE: Single-PID Wait Antipattern
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# The orchestrator loops through partition logs and launches mappers with '&'.
# However, it only preserves '$!' into a single variable ('last_pid=$!').
# When 'wait "$last_pid"' returns, earlier mappers are still executing, causing
# the reducer to run against incomplete data!
#
# TODO:
# 1. Declare an array: map_pids=()
# 2. Append each mapper PID: map_pids+=("$!")
# 3. Establish a cohort barrier wait: wait "${map_pids[@]}"

last_pid=""
log_info "Dispatching parallel partition mappers..."

for part in $PARTITION_PATTERN; do
    [[ -f "$part" ]] || continue

    log_info "Spawning mapper for partition: $part"
    bash "$MAPPER_CMD" "$part" &
    last_pid=$!
done

log_info "Awaiting mapper completion (BROKEN: waiting only for PID $last_pid)..."
wait "$last_pid"

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
  "reducer": "$REDUCER_CMD"
}
EOF

echo "ORCHESTRATION_COMPLETE"
