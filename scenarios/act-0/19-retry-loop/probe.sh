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
# - Track attempts (start at 1, max 4) and backoff delay
# - If ./mock_service.sh succeeds, output "SERVICE_READY" and exit 0
# - Otherwise, sleep for the current delay, increment attempt, and double the delay
# - If all attempts are exhausted, output "PROBE_TIMEOUT" to stderr and exit 1
