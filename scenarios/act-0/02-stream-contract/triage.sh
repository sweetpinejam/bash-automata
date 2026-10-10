#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.1: The Stream Contract
# ==============================================================================
# INSTRUCTIONS:
# Modify the function call below so that:
#   1. Standard data (stdout / FD 1) is redirected to: clean.log
#   2. Error diagnostics (stderr / FD 2) are redirected to: error.log
#
# SYNTAX TEMPLATE:
#   command > clean.log 2> error.log
# ==============================================================================
set -euo pipefail

simulate_noisy_probe() {
    echo "DATA: host=edge-01 status=healthy metric=42"
    echo "ERROR: connection timeout on port 8080" >&2
    echo "DATA: host=edge-02 status=healthy metric=88"
    echo "ERROR: memory threshold exceeded 85%" >&2
}

# TODO: Add file descriptor redirections to this command
simulate_noisy_probe
