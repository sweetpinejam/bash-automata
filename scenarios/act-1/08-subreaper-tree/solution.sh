#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Job Orchestrator (Process Tree Teardown)
# ==============================================================================
set -euo pipefail

rm -f pipeline.pid grandchildren.pids

# Launch the pipeline workload in background
bash pipeline.sh &
pipeline_pid=$!

sleep 0.2

echo "ORCHESTRATOR: Shutting down workload and all child processes..."

# Method: First terminate all child processes of the pipeline, then the pipeline itself
pkill -P "$pipeline_pid" 2>/dev/null || true
kill -TERM "$pipeline_pid" 2>/dev/null || true

wait "$pipeline_pid" 2>/dev/null || true
echo "TEARDOWN_FINISHED"
