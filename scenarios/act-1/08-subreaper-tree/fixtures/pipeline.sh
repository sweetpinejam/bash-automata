#!/usr/bin/env bash
# ==============================================================================
# Workload Pipeline: Multi-stage parallel stream processing workload
# ==============================================================================
# Spawns background worker tasks (grandchildren of the orchestrator).
# Without cascade teardown, these background workers survive as orphan tasks.
# ==============================================================================

set -euo pipefail

PIPELINE_PID_FILE="pipeline.pid"
GC_PIDS_FILE="grandchildren.pids"
STATUS_LOG="pipeline.log"

echo "$$" > "$PIPELINE_PID_FILE"
rm -f "$GC_PIDS_FILE" "$STATUS_LOG"

log_worker() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [PIPELINE] $*" >> "$STATUS_LOG"
}

log_worker "Booting 3 parallel stream worker tasks..."

# Spawn 3 grandchild background workers that perform simulated stream ingestion
for i in 1 2 3; do
    (
        worker_id="$i"
        worker_pid=$$
        log_worker "Worker $worker_id online (PID: $worker_pid)"
        while true; do
            # Simulate real workload CPU/sleep cycles
            sleep 0.1
        done
    ) >/dev/null 2>&1 &
    child_pid=$!
    echo "$child_pid" >> "$GC_PIDS_FILE"
    log_worker "Dispatched Worker $i with PID $child_pid"
done

log_worker "All 3 workers operational. Entering active monitoring event loop..."

# Keep pipeline process alive until signaled by orchestrator
while true; do
    sleep 0.1
done
