#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.01: The Space Landmine (Automated Cleanup Bot)
# ==============================================================================
# INSTRUCTIONS:
# This automated cleanup bot sweeps files from $SRC_DIR into $DEST_DIR.
# But because variables are unquoted, Bash splits on the space characters!
#
# Fix the unquoted variables below by wrapping them in double quotes:
#   "$DEST_DIR"   and   "$SRC_DIR"/*
# ==============================================================================
set -euo pipefail

SRC_DIR="deploy artifacts"
DEST_DIR="archived runs"

# TODO: Quote these variables to prevent Word Splitting!
mkdir -p $DEST_DIR
mv $SRC_DIR/* $DEST_DIR/

echo "SWEEP_COMPLETE"
