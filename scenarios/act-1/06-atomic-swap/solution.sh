#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Symlink Release Swapper (Atomic rename)
# ==============================================================================
set -euo pipefail

TARGET_RELEASE="${1:-releases/v2}"
TMP_LINK="current.tmp.$$"

# Step 1: Create temporary symlink pointing to the new release
ln -s "$TARGET_RELEASE" "$TMP_LINK"

# Step 2: Atomically swap over 'current' using mv -T (atomic rename system call)
mv -T "$TMP_LINK" current

echo "SWAP_COMPLETE"
