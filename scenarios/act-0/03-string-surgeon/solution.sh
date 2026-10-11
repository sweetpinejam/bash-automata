#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.03 (The String Surgeon)
# ==============================================================================
set -euo pipefail

INPUT_DIR="${1:-incoming}"
OUTPUT_DIR="${2:-catalog_out}"

[[ -d "$INPUT_DIR" ]] || { echo "Error: Input dir '$INPUT_DIR' not found" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"
: > "$OUTPUT_DIR/catalog.tsv"

PROCESSED_COUNT=0
declare -A SEEN_CATEGORIES

shopt -s nullglob
for filepath in "$INPUT_DIR"/*; do
    [[ -f "$filepath" ]] || continue

    # Step 1: Extract filename
    filename="${filepath##*/}"

    # Step 2: Extract compound/single extension and base stem
    case "$filename" in
        *.tar.gz)     ext="tar.gz"; stem="${filename%.tar.gz}" ;;
        *.tar.bz2)    ext="tar.bz2"; stem="${filename%.tar.bz2}" ;;
        *.tar.xz)     ext="tar.xz"; stem="${filename%.tar.xz}" ;;
        *.backup.sql) ext="backup.sql"; stem="${filename%.backup.sql}" ;;
        *.*)          ext="${filename##*.}"; stem="${filename%.*}" ;;
        *)            ext="none"; stem="$filename" ;;
    esac

    # Step 3: Determine category
    case "$ext" in
        tar.gz|tar.bz2|tar.xz|zip|gz) category="archives" ;;
        json|yaml|yml|toml|conf)      category="configs" ;;
        sql|backup.sql)               category="databases" ;;
        bin|sh|none)                  category="binaries" ;;
        *)                            category="miscellaneous" ;;
    esac

    SEEN_CATEGORIES["$category"]=1

    # Step 4: Create target directory and move
    target_dir="$OUTPUT_DIR/$category"
    mkdir -p "$target_dir"
    mv "$filepath" "$target_dir/$filename"

    # Step 5: Append to catalog
    printf "%s\t%s\t%s\t%s\n" "$filename" "$category" "$stem" "$ext" >> "$OUTPUT_DIR/catalog.tsv"

    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
done
shopt -u nullglob

UNIQUE_CATEGORIES="${#SEEN_CATEGORIES[@]}"

# Step 6: Summary output
echo "CATALOG_COMPLETE: processed=$PROCESSED_COUNT, categories=$UNIQUE_CATEGORIES"
