#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.09 (Stream-Safe While Loops)
# ==============================================================================
set -euo pipefail

STRIP_COMMENTS=0
declare -A VARS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strip-comments)
            STRIP_COMMENTS=1
            shift
            ;;
        --var)
            arg="${2:-}"
            [[ -n "$arg" ]] || { echo "Error: Missing argument for --var" >&2; exit 1; }
            key="${arg%%=*}"
            val="${arg#*=}"
            VARS["$key"]="$val"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

TEMPLATE_FILE="${1:-template.conf}"
OUTPUT_FILE="${2:-final.conf}"

[[ -f "$TEMPLATE_FILE" ]] || { echo "Error: Template '$TEMPLATE_FILE' not found" >&2; exit 1; }

: > "$OUTPUT_FILE"

TOTAL_LINES=0
WRITTEN_LINES=0
STRIPPED_LINES=0
SUBSTITUTED_COUNT=0

while IFS= read -r line || [[ -n "$line" ]]; do
    (( ++TOTAL_LINES ))

    # Check for comments if --strip-comments active
    if (( STRIP_COMMENTS == 1 )) && [[ "$line" =~ ^[[:space:]]*# ]]; then
        (( ++STRIPPED_LINES ))
        continue
    fi

    # Perform placeholder substitutions
    for key in "${!VARS[@]}"; do
        placeholder="{{$key}}"
        if [[ "$line" == *"$placeholder"* ]]; then
            val="${VARS[$key]}"
            line="${line//$placeholder/$val}"
            (( ++SUBSTITUTED_COUNT ))
        fi
    done

    echo "$line" >> "$OUTPUT_FILE"
    (( ++WRITTEN_LINES ))
done < "$TEMPLATE_FILE"

echo "COMPILER_SUMMARY: total=$TOTAL_LINES, written=$WRITTEN_LINES, stripped=$STRIPPED_LINES, substituted=$SUBSTITUTED_COUNT, output=$OUTPUT_FILE"
