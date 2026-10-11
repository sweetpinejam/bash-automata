#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Canary Health Probe with Consecutive Failure Latch
# ==============================================================================
set -euo pipefail

CYCLES=10
FAIL_THRESHOLD=3
consecutive_fails=0

for (( i=1; i<=CYCLES; i++ )); do
  if python3 health_endpoint.py; then
    consecutive_fails=0
  else
    (( consecutive_fails += 1 ))
    if (( consecutive_fails >= FAIL_THRESHOLD )); then
      echo "CANARY_ABORTED: Threshold of $FAIL_THRESHOLD consecutive failures reached on cycle $i" >&2
      exit 1
    fi
  fi
  sleep 0.01
done

echo "CANARY_HEALTHY"
exit 0
