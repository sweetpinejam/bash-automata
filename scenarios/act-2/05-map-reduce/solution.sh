#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Map-Reduce Analytics Orchestrator
# Implements parallel cohort PID tracking and array barrier wait.
# ==============================================================================
set -euo pipefail

rm -f summary_part_*.tsv final_metrics.json

map_pids=()

for part in part_*.log; do
  [[ -f "$part" ]] || continue
  bash mapper.sh "$part" &
  map_pids+=("$!")
done

# Barrier synchronization: Wait for all mappers to finish writing
wait "${map_pids[@]}"

# Safe reduction
python3 reducer.py

echo "ORCHESTRATION_COMPLETE"
