#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Automated Service Readiness Probe
# ==============================================================================
set -euo pipefail

attempt=1
max_attempts=4
delay_ms=20

while (( attempt <= max_attempts )); do
  if ./mock_service.sh; then
    echo "SERVICE_READY"
    exit 0
  fi
  sleep "0.0$delay_ms"
  (( attempt += 1 ))
  (( delay_ms *= 2 ))
done

echo "PROBE_TIMEOUT" >&2
exit 1
