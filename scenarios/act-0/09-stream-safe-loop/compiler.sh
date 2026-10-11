#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.09: Stream-Safe While Loops (High-Fidelity Config Compiler)
# ==============================================================================
# INSTRUCTIONS:
# Implement a high-fidelity configuration compiler in pure Bash.
#
# HARD CONSTRAINT:
# Strictly NO 'for ... in $(cat ...)' or '$(<...)' loops!
# All line reading MUST use:
#   while IFS= read -r line || [[ -n "$line" ]]; do ... done < "$template_file"
#
# Arguments:
#   [--strip-comments]
#   [--var KEY=VAL ...]
#   <template_file> (default: "template.conf")
#   <output_file>   (default: "final.conf")
#
# Requirements:
# 1. Parse optional `--strip-comments` flag.
# 2. Parse zero or more `--var KEY=VAL` flags into an associative array.
# 3. Stream-safe line reading preserving leading/trailing spaces, tabs, and backslashes.
# 4. If `--strip-comments` is active:
#    - Skip any line where the first non-whitespace character is '#'.
# 5. Substitute all `{{KEY}}` placeholders with corresponding values.
# 6. Write rendered lines to $OUTPUT_FILE.
# 7. Print summary:
#    "COMPILER_SUMMARY: total=<T>, written=<W>, stripped=<S>, substituted=<V>, output=<out>"
# ==============================================================================
set -euo pipefail

STRIP_COMMENTS=0
declare -A VARS=()

# --- STEP 1: PARSE CLI FLAGS & ARGUMENTS ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --strip-comments)
            STRIP_COMMENTS=1
            shift
            ;;
        --var)
            # Format: KEY=VAL
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

# --- STEP 2: STREAM-SAFE COMPILATION LOOP ---
# TODO: Implement line-by-line streaming using the canonical POSIX idiom:
# while IFS= read -r line || [[ -n "$line" ]]; do
# Inside loop:
#   1. Increment TOTAL_LINES
#   2. If STRIP_COMMENTS is 1 and line starts with optional spaces followed by '#':
#      Increment STRIPPED_LINES and continue.
#   3. For each key in "${!VARS[@]}":
#      Check if line contains "{{$key}}". If so, replace with "${VARS[$key]}" and increment SUBSTITUTED_COUNT.
#   4. Output line to "$OUTPUT_FILE" and increment WRITTEN_LINES.


# --- STEP 3: SUMMARY METRICS ---
echo "COMPILER_SUMMARY: total=$TOTAL_LINES, written=$WRITTEN_LINES, stripped=$STRIPPED_LINES, substituted=$SUBSTITUTED_COUNT, output=$OUTPUT_FILE"
