#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Dynamic Worker Pool Manager
# Replaces lockstep batch stalls with dynamic slot replenishment using wait -n.
# ==============================================================================
set -euo pipefail

QUEUE_FILE="incoming.queue"
MAX_WORKERS=3
active=0

while IFS= read -r task || [[ -n "$task" ]]; do
  [[ -n "$task" ]] || continue

  python3 worker.py "$task" &
  (( active += 1 ))

  # Dynamic slot replenishment: wait for ANY worker to complete
  if (( active >= MAX_WORKERS )); then
    wait -n
    (( active -= 1 ))
  fi
done < "$QUEUE_FILE"

# Wait for remaining active workers to drain
wait

echo "POOL_DRAINED"
