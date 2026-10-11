#!/usr/bin/env bash
# ==============================================================================
# Map-Reduce Analytics Orchestrator
# Incident: The reducer executes prematurely before all parallel mappers finish,
# corrupting the metric ledger and dropping up to 75% of processed log data!
# Target: Track all background mapper subshell PIDs in a Bash array and establish
# a barrier wait ("wait ${map_pids[@]}") before invoking the reducer.
# ==============================================================================
set -euo pipefail

rm -f summary_part_*.tsv final_metrics.json

# BROKEN / INCOMPLETE BARRIER:
# Launches mappers in parallel, but only tracks the last PID ($!):
last_pid=""
for part in part_*.log; do
  [[ -f "$part" ]] || continue
  bash mapper.sh "$part" &
  last_pid=$!
done

# BUG: Only waits for the last single job instead of all mappers!
wait "$last_pid"

python3 reducer.py
echo "ORCHESTRATION_COMPLETE"
