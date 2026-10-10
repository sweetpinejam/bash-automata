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

# TODO: Refactor using atomic mkdir:
# 1. Attempt atomic directory creation:
#    mkdir "$LOCK_DIR" 2>/dev/null || { echo "LOCK_ACQUIRE_FAILED"; exit 1; }
# 2. Register EXIT trap to guarantee lock directory cleanup:
#    trap 'rmdir "$LOCK_DIR"' EXIT

echo "SYNC_RUNNING"
# Simulate short sync task
sleep 0.1
echo "SYNC_SUCCESS"

# In the broken version, manual cleanup runs only if no error occurred
rmdir "$LOCK_DIR"
