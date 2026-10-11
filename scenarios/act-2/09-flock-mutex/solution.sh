#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Shared Metrics Dump Writer with Kernel Advisory Locks
# ==============================================================================
set -euo pipefail

WORKER_ID="${1:-worker_1}"
OUTPUT_FILE="metrics_dump.tsv"
LOCK_FILE="metrics.lock"

exec 200>"$LOCK_FILE"

for (( i=1; i<=10; i++ )); do
  flock -x 200

  echo "START_ROW" >> "$OUTPUT_FILE"
  sleep 0.005
  echo -e "worker=$WORKER_ID\tseq=$i\tdata=payload_$i" >> "$OUTPUT_FILE"
  echo "END_ROW" >> "$OUTPUT_FILE"

  flock -u 200
done

exec 200>&-
