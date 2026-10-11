#!/usr/bin/env bash
# ==============================================================================
# Dynamic Worker Pool Manager
# Incident: Lockstep batching wastes worker capacity. Waiting for all workers
# to finish simultaneously blocks fast workers from taking new queue items.
# Target: Dynamic slot replenishment — refill worker capacity immediately
# whenever ANY background worker finishes.
# ==============================================================================
set -euo pipefail

QUEUE_FILE="incoming.queue"
MAX_WORKERS=3
active=0

# BROKEN / LOCKSTEP BATCHING:
# Waits for ALL workers to terminate before scheduling the next batch:
while IFS= read -r task || [[ -n "$task" ]]; do
  [[ -n "$task" ]] || continue

  python3 worker.py "$task" &
  (( active += 1 ))

  # Lockstep barrier stalls the pipeline:
  if (( active >= MAX_WORKERS )); then
    wait
    active=0
  fi
done < "$QUEUE_FILE"

wait
echo "POOL_DRAINED"
