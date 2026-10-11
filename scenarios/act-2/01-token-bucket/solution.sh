#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: The Token Bucket Semaphore
# Implements POSIX FIFO counting semaphore to strictly bound concurrency to N=4.
# ==============================================================================
set -euo pipefail

QUEUE_FILE="queue.txt"
CONCURRENCY=4

FIFO="/tmp/sem_$$.fifo"
mkfifo "$FIFO"
trap 'rm -f "$FIFO"; exec 3>&- 2>/dev/null || true' EXIT INT TERM

# Open FD 3 for bidirectional FIFO communication
exec 3<>"$FIFO"
rm -f "$FIFO"

# Pre-seed semaphore with 4 worker slots
for (( i=0; i<CONCURRENCY; i++ )); do
  echo >&3
done

while IFS= read -r item || [[ -n "$item" ]]; do
  [[ -n "$item" ]] || continue

  # Acquire token (blocks if bucket is empty)
  read -u 3

  (
    python3 mock_api.py "$item"
    # Release token back to semaphore pool
    echo >&3
  ) &
done < "$QUEUE_FILE"

wait
exec 3>&-

echo "DISPATCH_COMPLETE"
