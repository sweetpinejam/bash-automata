#!/usr/bin/env bash
# ==============================================================================
# Job Orchestrator
# Problem: Kills only the immediate child, leaving grandchildren running!
# ==============================================================================
set -euo pipefail

rm -f pipeline.pid grandchildren.pids

# Launch the pipeline workload in background
bash pipeline.sh &
pipeline_pid=$!

# Wait for pipeline and grandchildren to initialize
sleep 0.2

echo "ORCHESTRATOR: Shutting down workload..."

# BROKEN: Standard kill terminates ONLY $pipeline_pid!
# The 3 grandchildren in grandchildren.pids survive and keep running forever!
kill -TERM "$pipeline_pid" 2>/dev/null || true

# TODO: Kill the entire process group, or ensure pipeline.sh traps EXIT and kills its group:
# kill -TERM -- "-$pipeline_pid" 2>/dev/null || true

wait "$pipeline_pid" 2>/dev/null || true
echo "TEARDOWN_FINISHED"
