#!/usr/bin/env bash
# ==============================================================================
# Transaction Queue Worker
# Incident: When container orchestrators send SIGTERM to roll out a new image,
# this worker terminates instantly mid-flight, severing active database
# transactions and leaving orphaned half-committed records in the database!
# Target: Implement graceful drain on SIGTERM/SIGINT:
#   1. Set a DRAINING flag upon receiving SIGTERM
#   2. Complete the currently in-flight transaction
#   3. Stop picking up new work from the queue
#   4. Log 'DRAIN_COMPLETED' and exit cleanly with code 0
# ==============================================================================
set -euo pipefail

QUEUE_FILE="jobs.queue"
COMMIT_LOG="transactions.commit"
DRAIN_LOG="drain.log"
PID_FILE="worker.pid"

echo "$$" > "$PID_FILE"

# BROKEN / NO DRAIN TRAP:
# No signal handler. SIGTERM violently terminates the process immediately:
while IFS= read -r job || [[ -n "$job" ]]; do
  [[ -n "$job" ]] || continue

  # In-flight transaction begins:
  echo "TX_START: $job" >> "$COMMIT_LOG"

  # Simulate network / database commit window
  sleep 0.1

  # In-flight transaction finishes:
  echo "TX_COMMITTED: $job" >> "$COMMIT_LOG"
done < "$QUEUE_FILE"

rm -f "$PID_FILE"
echo "QUEUE_EXHAUSTED"
