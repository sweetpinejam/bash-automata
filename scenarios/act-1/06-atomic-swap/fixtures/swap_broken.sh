#!/usr/bin/env bash
# ==============================================================================
# Symlink Release Swapper
# Problem: Non-atomic deletion causes transient missing-file errors!
# ==============================================================================
set -euo pipefail

TARGET_RELEASE="${1:-releases/v2}"

# BROKEN / NON-ATOMIC:
# Removing 'current' leaves a vulnerability window where 'current' does not exist!
# Active web workers hit 404s!
rm -f current
# Brief pause simulates filesystem latency
sleep 0.05
ln -s "$TARGET_RELEASE" current

echo "SWAP_COMPLETE"
