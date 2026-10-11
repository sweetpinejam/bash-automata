#!/usr/bin/env bash
# ==============================================================================
# Automated Canary Health Probe
# Incident: Single transient network blips immediately trigger false-positive
# deployment rollbacks, causing constant canary release flapping!
# Target: Implement a consecutive failure latch: require 3 CONSECUTIVE failures
# before failing the canary. Any success must reset the failure counter.
# ==============================================================================
set -euo pipefail

CYCLES=10
FAIL_THRESHOLD=3
consecutive_fails=0

# BROKEN / ZERO TOLERANCE:
# Aborts on the very first transient error, failing healthy deployments:
for (( i=1; i<=CYCLES; i++ )); do
  if ! python3 health_endpoint.py; then
    echo "CANARY_ABORTED: Probe failed on cycle $i" >&2
    exit 1
  fi
  sleep 0.01
done

echo "CANARY_HEALTHY"
exit 0
