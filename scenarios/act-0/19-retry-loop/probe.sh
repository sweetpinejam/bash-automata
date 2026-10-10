#!/usr/bin/env bash
# ==============================================================================
# Automated Service Readiness Probe
# Objective: Implement retry loop with exponential backoff
# Target: Service succeeds on attempt 3. Max attempts: 4.
# ==============================================================================
set -euo pipefail

# BROKEN: Single naive attempt fails because the service needs warm-up time!
if ./mock_service.sh; then
  echo "SERVICE_READY"
  exit 0
else
  echo "PROBE_TIMEOUT" >&2
  exit 1
fi

# TODO: Refactor using a while loop with exponential backoff:
# attempt=1
# max_attempts=4
# delay_ms=20
#
# while (( attempt <= max_attempts )); do
#   if ./mock_service.sh; then
#     echo "SERVICE_READY"
#     exit 0
#   fi
#   sleep "0.0$delay_ms"
#   (( attempt += 1 ))
#   (( delay_ms *= 2 ))
# done
# echo "PROBE_TIMEOUT" >&2
# exit 1
