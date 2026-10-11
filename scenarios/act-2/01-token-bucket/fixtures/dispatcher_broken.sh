#!/usr/bin/env bash
# ==============================================================================
# Batch Dispatcher Bot
# Incident: Firing all 20 jobs simultaneously triggers HTTP 429 rate limit bans!
# Target: Regulate parallel execution to at most 4 concurrent worker subshells.
# Constraint: Pure Bash FIFO / FD token bucket semaphore (no xargs -P, no parallel).
# ==============================================================================
set -euo pipefail

QUEUE_FILE="queue.txt"

# BROKEN / UNTHROTTLED:
# Fires all jobs into the background concurrently without any semaphore:
while IFS= read -r item || [[ -n "$item" ]]; do
  [[ -n "$item" ]] || continue
  (
    python3 mock_api.py "$item"
  ) &
done < "$QUEUE_FILE"

wait
echo "DISPATCH_COMPLETE"
