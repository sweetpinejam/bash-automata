#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.04 (Pure In-Memory Replace)
# ==============================================================================
set -euo pipefail

INPUT_FILE="${1:-events.raw}"
OUTPUT_FILE="${2:-events.sanitized}"

[[ -f "$INPUT_FILE" ]] || { echo "Error: Input file '$INPUT_FILE' not found" >&2; exit 1; }

: > "$OUTPUT_FILE"

TOTAL_LINES=0
MODIFIED_LINES=0

# --- STEP 1: STREAM-SAFE SANITIZATION LOOP ---
while IFS= read -r line || [[ -n "$line" ]]; do
    TOTAL_LINES=$((TOTAL_LINES + 1))
    original="$line"

    # 1. Prefix replacement
    line="${line/#DEBUG:/[TRACE]:}"

    # 2. Global replacements
    line="${line//dev.internal/prod.external}"
    line="${line//SECRET_/REDACTED_}"

    # 3. Suffix scrubbing (?session=*)
    line="${line/%\?session=*/}"

    if [[ "$line" != "$original" ]]; then
        MODIFIED_LINES=$((MODIFIED_LINES + 1))
    fi

    echo "$line" >> "$OUTPUT_FILE"
done < "$INPUT_FILE"

# --- STEP 2: GENERATE AUDIT METRICS JSON ---
cat <<EOF > "audit_metrics.json"
{
  "status": "SANITIZED",
  "total_lines": $TOTAL_LINES,
  "lines_modified": $MODIFIED_LINES,
  "engine": "bash_in_memory"
}
EOF

# --- STEP 3: EMIT SUMMARY METRICS ---
echo "SANITIZATION_COMPLETE: total=$TOTAL_LINES, modified=$MODIFIED_LINES, output=$OUTPUT_FILE"
