#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION & POST-MORTEM: Drill 0.1
# ==============================================================================
# In POSIX systems, streams are split by file descriptors:
#   > clean.log   Redirects File Descriptor 1 (standard output)
#   2> error.log  Redirects File Descriptor 2 (standard error)
#
# Applying both on the same invocation separates data from diagnostic noise.
# ==============================================================================
set -euo pipefail

simulate_noisy_probe() {
    echo "DATA: host=edge-01 status=healthy metric=42"
    echo "ERROR: connection timeout on port 8080" >&2
    echo "DATA: host=edge-02 status=healthy metric=88"
    echo "ERROR: memory threshold exceeded 85%" >&2
}

simulate_noisy_probe > clean.log 2> error.log
