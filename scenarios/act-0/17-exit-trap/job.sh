#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.3: The Exit Trap
# ==============================================================================
# INSTRUCTIONS:
# This job creates a lock file. If the process terminates normally or via a signal,
# the lock file must be guaranteed to be removed automatically!
#
# Register an automated exit and signal cleanup trap.
# ==============================================================================
set -euo pipefail

LOCK_FILE="./job.lock"

# TODO: Register your cleanup trap here BEFORE creating the lock file

echo "$$" > "$LOCK_FILE"
echo "Acquired lock: $LOCK_FILE (PID: $$)"

# Simulated work
sleep 1

echo "Job completed successfully."
