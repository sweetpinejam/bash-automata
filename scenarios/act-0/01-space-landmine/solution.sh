#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.01 (The Space Landmine)
# ==============================================================================
set -euo pipefail

DRY_RUN=0
TOTAL_FILES=0
TOTAL_BYTES=0

# --- STEP 1: PARSE ARGUMENTS & FLAGS ---
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 [--dry-run] <source_dir> <dest_dir>" >&2
    exit 1
fi

SRC_DIR="$1"
DEST_DIR="$2"

if [[ ! -d "$SRC_DIR" ]]; then
    echo "Error: Source directory '$SRC_DIR' does not exist." >&2
    exit 1
fi

# --- STEP 2: PREPARE DESTINATION (LIVE MODE ONLY) ---
if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$DEST_DIR"
    : > "$DEST_DIR/manifest.tsv"
fi

# --- STEP 3: SCAN & ARCHIVE FILES SAFELY ---
while IFS= read -r -d '' file; do
    [[ -f "$file" ]] || continue

    bytes=$(wc -c < "$file")
    TOTAL_BYTES=$((TOTAL_BYTES + bytes))
    TOTAL_FILES=$((TOTAL_FILES + 1))

    filename="${file##*/}"
    target_path="$DEST_DIR/$filename"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[DRY_RUN] Would move: $file -> $target_path"
    else
        mv "$file" "$target_path"
        printf "%s\t%d\n" "$filename" "$bytes" >> "$DEST_DIR/manifest.tsv"
    fi
done < <(find "$SRC_DIR" -type f -print0)

# --- STEP 4: EMIT SUMMARY METRICS ---
echo "SWEEP_COMPLETE: files=$TOTAL_FILES, bytes=$TOTAL_BYTES, dry_run=$DRY_RUN"
