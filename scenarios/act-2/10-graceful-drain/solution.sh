#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Transaction Queue Worker with Graceful Drain
# ==============================================================================
set -euo pipefail

QUEUE_FILE="jobs.queue"
COMMIT_LOG="transactions.commit"
DRAIN_LOG="drain.log"
PID_FILE="worker.pid"

echo "$$" > "$PID_FILE"

draining=false
handle_term() {
  draining=true
}
trap handle_term TERM INT

while IFS= read -r job || [[ -n "$job" ]]; do
  [[ -n "$job" ]] || continue

  if $draining; then
    break
  fi

  echo "TX_START: $job" >> "$COMMIT_LOG"
  sleep 0.1
  echo "TX_COMMITTED: $job" >> "$COMMIT_LOG"

  if $draining; then
    break
  fi
done < "$QUEUE_FILE"

echo "DRAIN_COMPLETED" > "$DRAIN_LOG"
rm -f "$PID_FILE"
echo "QUEUE_DRAINED"
exit 0
