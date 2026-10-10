#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Automated Database Sync Worker
# ==============================================================================
set -euo pipefail

LOCK_DIR="sync.lock"

# Atomic mutual exclusion lock using mkdir
mkdir "$LOCK_DIR" 2>/dev/null || {
  echo "LOCK_ACQUIRE_FAILED"
  exit 1
}

# Guaranteed unlock on script exit (even if killed or on error)
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

echo "SYNC_RUNNING"
sleep 0.1
echo "SYNC_SUCCESS"
