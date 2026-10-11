#!/usr/bin/env bash
# ==============================================================================
# Workload Pipeline: Spawns 3 long-running grandchild background workers
# ==============================================================================
set -euo pipefail

echo "$$" > pipeline.pid

# Spawn 3 grandchild worker tasks that loop
for i in 1 2 3; do
  (
    while true; do
      sleep 0.1
    done
  ) &
  echo "$!" >> grandchildren.pids
done

# Keep pipeline active
while true; do
  sleep 0.1
done
