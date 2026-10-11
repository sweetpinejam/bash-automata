#!/usr/bin/env bash
# ==============================================================================
# Shared Metrics Dump Writer
# Incident: Concurrent worker jobs write simultaneously to metrics_dump.tsv.
# Without mutual exclusion, multi-line row blocks tear and interleave!
# Target: Protect the write critical section using Linux kernel 'flock' on
# dedicated file descriptor 200 so each worker writes its batch atomically.
# ==============================================================================
set -euo pipefail

WORKER_ID="${1:-worker_1}"
OUTPUT_FILE="metrics_dump.tsv"
LOCK_FILE="metrics.lock"

# BROKEN / UNLOCKED:
# Writes directly to shared file concurrently with other background processes:
for (( i=1; i<=10; i++ )); do
  echo "START_ROW" >> "$OUTPUT_FILE"
  # Sleep slightly between line writes to increase race collision probability
  sleep 0.005
  echo -e "worker=$WORKER_ID\tseq=$i\tdata=payload_$i" >> "$OUTPUT_FILE"
  echo "END_ROW" >> "$OUTPUT_FILE"
done
