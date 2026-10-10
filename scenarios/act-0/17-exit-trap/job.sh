#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.3: The Exit Trap
# ==============================================================================
# INSTRUCTIONS:
# This job creates a lock file. If the process is killed or finishes, the lock
# file must be removed automatically!
#
# Register a trap near the top of the script:
#   trap 'rm -f "$LOCK_FILE"' EXIT INT TERM
# ==============================================================================
set -euo pipefail

LOCK_FILE="./job.lock"

# TODO: Register your cleanup trap here BEFORE creating the lock file

echo "$$" > "$LOCK_FILE"
echo "Acquired lock: $LOCK_FILE (PID: $$)"

# Simulated work
sleep 1

echo "Job completed successfully."
