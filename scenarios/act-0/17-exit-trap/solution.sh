#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION & POST-MORTEM: Drill 0.3
# ==============================================================================
# In production automation, processes die unpredictably (OOM killer, user Ctrl+C,
# orchestrator SIGTERM, or sudden errors).
#
# Registering 'trap ... EXIT INT TERM' guarantees cleanup:
#   EXIT  Fires on any exit (clean exit, 'exit 1', or error with 'set -e')
#   INT   Fires when interrupted by keyboard (Ctrl+C / SIGINT)
#   TERM  Fires when terminated by an orchestrator or supervisor (SIGTERM)
# ==============================================================================
set -euo pipefail

LOCK_FILE="./job.lock"

# Defensive trap registered BEFORE creating the file
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

echo "$$" > "$LOCK_FILE"
echo "Acquired lock: $LOCK_FILE (PID: $$)"

# Simulated work
sleep 1

echo "Job completed successfully."
