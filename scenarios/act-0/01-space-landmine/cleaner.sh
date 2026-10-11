#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.01: The Space Landmine (Whitespace-Resilient Archival Bot)
# ==============================================================================
# INSTRUCTIONS:
# Complete this automated cleanup and archival utility.
# The source directory contains nested folders and files with SPACES in names.
#
# Requirements:
# 1. Parse optional `--dry-run` flag as first argument (set DRY_RUN=1, then shift).
# 2. Ensure exactly 2 arguments remain: <source_dir> and <dest_dir>.
#    If not, print usage to stderr and exit 1.
# 3. Verify that <source_dir> exists and is a directory; if not, exit 1.
# 4. If live run (DRY_RUN=0):
#    - Create <dest_dir> safely.
#    - Initialize <dest_dir>/manifest.tsv (empty file).
# 5. Scan all files in <source_dir> using a whitespace-safe loop.
#    For each file:
#    - Calculate size in bytes (wc -c < "$file").
#    - Accumulate TOTAL_FILES and TOTAL_BYTES.
#    - If DRY_RUN=1:
#      echo "[DRY_RUN] Would move: $file -> $dest_path"
#    - If DRY_RUN=0:
#      Move the file into <dest_dir>/ and append "<filename>\t<bytes>" to manifest.tsv.
# 6. Output final summary:
#    "SWEEP_COMPLETE: files=<COUNT>, bytes=<TOTAL_BYTES>, dry_run=<0|1>"
# ==============================================================================
set -euo pipefail

DRY_RUN=0
TOTAL_FILES=0
TOTAL_BYTES=0

# --- STEP 1: PARSE ARGUMENTS & FLAGS ---
# TODO: Check if $1 is "--dry-run". If so, set DRY_RUN=1 and shift.


# TODO: Validate that exactly 2 arguments remain ($1=SRC_DIR, $2=DEST_DIR).
# If not, echo usage message to stderr and exit 1.


# TODO: Assign SRC_DIR and DEST_DIR from positional parameters.
# Ensure expansions are protected against word splitting!
SRC_DIR=""
DEST_DIR=""

# TODO: Check if $SRC_DIR exists and is a directory. If not, exit 1.


# --- STEP 2: PREPARE DESTINATION (LIVE MODE ONLY) ---
if [[ "$DRY_RUN" -eq 0 ]]; then
    # TODO: Create $DEST_DIR safely and initialize $DEST_DIR/manifest.tsv
    :
fi

# --- STEP 3: SCAN & ARCHIVE FILES SAFELY ---
# TODO: Iterate over all files in $SRC_DIR safely without word splitting.
# Hint: Use 'while IFS= read -r -d "" file; do ... done < <(find "$SRC_DIR" -type f -print0)'
# Inside the loop:
#   1. [[ -f "$file" ]] || continue
#   2. Compute file byte size and add to TOTAL_BYTES, increment TOTAL_FILES
#   3. If DRY_RUN == 1:
#        echo "[DRY_RUN] Would move: $file -> $DEST_DIR/$(basename "$file")"
#      Else:
#        mv "$file" into "$DEST_DIR/"
#        append "$(basename "$file")\t$bytes" to "$DEST_DIR/manifest.tsv"


# --- STEP 4: EMIT SUMMARY METRICS ---
echo "SWEEP_COMPLETE: files=$TOTAL_FILES, bytes=$TOTAL_BYTES, dry_run=$DRY_RUN"
