#!/usr/bin/env bash
# ==============================================================================
# Batch Job Supervisor
# Problem: Spawns background worker tasks but never reaps them!
# ==============================================================================
set -euo pipefail

done_file="batch.done"
rm -f "$done_file"

TOTAL_TASKS=20

for (( i=1; i<=TOTAL_TASKS; i++ )); do
  # Spawn background worker that completes quickly
  (
    echo "TASK_$i: DONE" >> "$done_file"
    exit 0
  ) &
done

# BUG: Sleeps without calling 'wait', leaving 20 zombie processes in the kernel table!
sleep 0.5

# TODO: Reap all background child worker processes so no zombies remain in the process table.

echo "SUPERVISOR_DONE"
