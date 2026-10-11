#!/usr/bin/env bash
# ==============================================================================
# Automated Database Sync Worker
# Problem: Non-atomic file check permits concurrent runs
# ==============================================================================
set -euo pipefail

LOCK_DIR="sync.lock"

# BROKEN / RACE CONDITION:
# if [ -f sync.lock ] followed by touch is vulnerable to TOCTOU race conditions!
if [ -d "$LOCK_DIR" ]; then
  echo "LOCK_ACQUIRE_FAILED"
  exit 1
fi
mkdir -p "$LOCK_DIR"

# TODO: Implement atomic mutex locking and cleanup:
# 1. Attempt atomic directory creation; abort with LOCK_ACQUIRE_FAILED if it already exists
# 2. Register an EXIT trap to ensure the lock directory is unlinked upon completion

echo "SYNC_RUNNING"
# Simulate short sync task
sleep 0.1
echo "SYNC_SUCCESS"

# In the broken version, manual cleanup runs only if no error occurred
rmdir "$LOCK_DIR"
