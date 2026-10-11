#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Batch Job Supervisor
# ==============================================================================
set -euo pipefail

done_file="batch.done"
rm -f "$done_file"

TOTAL_TASKS=20

for (( i=1; i<=TOTAL_TASKS; i++ )); do
  (
    echo "TASK_$i: DONE" >> "$done_file"
    exit 0
  ) &
done

# Actively reap all background child processes to prevent zombie table accumulation:
wait

echo "SUPERVISOR_DONE"
