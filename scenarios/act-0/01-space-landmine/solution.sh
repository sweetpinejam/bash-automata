#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION & POST-MORTEM: Lesson 0.01 (The Space Landmine)
# ==============================================================================
# In Bash, whitespace acts as the Internal Field Separator (IFS).
# Whenever a variable contains spaces, unquoted expansion breaks it into
# multiple distinct arguments:
#   mkdir -p $DEST_DIR  ->  mkdir -p archived runs (creates 2 folders!)
#
# Double-quoting prevents Word Splitting:
#   mkdir -p "$DEST_DIR" -> Passes ONE single argument to mkdir.
#   mv "$SRC_DIR"/* "$DEST_DIR"/ -> Correctly preserves filenames with spaces.
# ==============================================================================
set -euo pipefail

SRC_DIR="deploy artifacts"
DEST_DIR="archived runs"

mkdir -p "$DEST_DIR"
mv "$SRC_DIR"/* "$DEST_DIR"/

echo "SWEEP_COMPLETE"
