#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.01: The Space Landmine (Automated Cleanup Bot)
# ==============================================================================
# INSTRUCTIONS:
# This automated cleanup bot sweeps files from $SRC_DIR into $DEST_DIR.
# But directory and file names contain space characters, causing word splitting!
#
# Harden the commands below to safely handle whitespace in paths.
# ==============================================================================
set -euo pipefail

SRC_DIR="deploy artifacts"
DEST_DIR="archived runs"

# TODO: Harden directory creation and file movement against word splitting
mkdir -p $DEST_DIR
mv $SRC_DIR/* $DEST_DIR/

echo "SWEEP_COMPLETE"
