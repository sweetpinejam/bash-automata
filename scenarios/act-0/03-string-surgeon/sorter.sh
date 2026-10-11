#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.03: The String Surgeon (High-Performance In-Memory Cataloguer)
# ==============================================================================
# INSTRUCTIONS:
# Implement an artifact indexing and categorization bot in PURE Bash.
#
# HARD CONSTRAINT:
# Strictly NO external commands: basename, dirname, cut, sed, awk, tr, perl, python.
# All path extraction, extension parsing, and stem trimming MUST use native
# parameter expansion (${VAR##*/}, ${VAR%/*}, ${VAR%.*}, etc.).
#
# Requirements:
# 1. Positional arguments:
#    $1 = input directory (default: "incoming")
#    $2 = output directory (default: "catalog_out")
# 2. Iterate over all files in input directory safely.
# 3. For each file, extract in-memory:
#    - filename: strip directory prefix
#    - ext: compound extension (.tar.gz, .tar.bz2, .tar.xz, .backup.sql),
#           or standard extension (.json -> json), or "none" if no dot exists.
#    - stem: filename with extension stripped
# 4. Determine category:
#    - "archives": tar.gz, tar.bz2, tar.xz, zip, gz
#    - "configs": json, yaml, yml, toml, conf
#    - "databases": sql, backup.sql
#    - "binaries": bin, sh, or none
#    - "miscellaneous": any other extension
# 5. Move file to <output_dir>/<category>/<filename>
# 6. Append to <output_dir>/catalog.tsv:
#    "<filename>\t<category>\t<stem>\t<ext>"
# 7. Print summary:
#    "CATALOG_COMPLETE: processed=<N>, categories=<M>"
# ==============================================================================
set -euo pipefail

INPUT_DIR="${1:-incoming}"
OUTPUT_DIR="${2:-catalog_out}"

[[ -d "$INPUT_DIR" ]] || { echo "Error: Input dir '$INPUT_DIR' not found" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"
: > "$OUTPUT_DIR/catalog.tsv"

PROCESSED_COUNT=0
declare -A SEEN_CATEGORIES

# TODO: Iterate over files in "$INPUT_DIR" without external tools.
# Remember: Globbing handles spaces safely if quoted properly.
shopt -s nullglob
for filepath in "$INPUT_DIR"/*; do
    [[ -f "$filepath" ]] || continue

    # TODO: Step 1 - Extract filename using parameter expansion (strip leading path)
    filename=""

    # TODO: Step 2 - Extract compound or single extension, and base stem
    # Hints:
    # Check *.tar.gz, *.tar.bz2, *.tar.xz, *.backup.sql
    # Check standard *.* (${filename##*.} and ${filename%.*})
    # If no dot: ext="none", stem="$filename"
    ext=""
    stem=""

    # TODO: Step 3 - Map extension to category (archives, configs, databases, binaries, miscellaneous)
    category=""

    # Record seen category
    SEEN_CATEGORIES["$category"]=1

    # TODO: Step 4 - Create category folder, move file, and log to catalog.tsv
    # Format: printf "%s\t%s\t%s\t%s\n" "$filename" "$category" "$stem" "$ext" >> "$OUTPUT_DIR/catalog.tsv"

    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
done
shopt -u nullglob

UNIQUE_CATEGORIES="${#SEEN_CATEGORIES[@]}"

# --- STEP 5: OUTPUT SUMMARY METRICS ---
echo "CATALOG_COMPLETE: processed=$PROCESSED_COUNT, categories=$UNIQUE_CATEGORIES"
