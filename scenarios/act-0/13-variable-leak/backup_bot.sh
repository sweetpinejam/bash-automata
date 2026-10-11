#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.13: The Variable Leak (Function Scoping & Local Defense)
# ==============================================================================
# INSTRUCTIONS:
# Implement a multi-day automated partition archiver in pure Bash.
#
# HARD CONSTRAINT:
# All variables inside helper functions MUST be declared with 'local'.
# No function may leak variables or clobber caller loop counters!
#
# Arguments:
#   [--days <N>] (default: 5)
#   [--manifest <file>] (default: "backup_manifest.tsv")
#
# Requirements:
# 1. Parse optional `--days <N>` and `--manifest <file>`.
# 2. Function `process_day_chunks()`:
#    - Accepts `$1` = day number.
#    - Iterates chunks 1..3 for that day.
#    - Scopes all variables locally with 'local'.
#    - Simulates processing chunks into spool.
# 3. Function `archive_day()`:
#    - Accepts `$1` = day number.
#    - Calls `process_day_chunks "$1"`.
#    - Appends record to manifest: "DAY_<N>\t3\tSUCCESS".
# 4. Main loop iterates day_id from 1 to DAYS:
#    - Calls `archive_day "$day_id"`.
#    - Must complete all days without premature loop termination!
# 5. Output summary:
#    "BACKUP_BOT_COMPLETE: days=<N>, total_chunks=<T>, manifest=<path>"
# ==============================================================================
set -euo pipefail

TOTAL_DAYS=5
MANIFEST_FILE="backup_manifest.tsv"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --days)
            TOTAL_DAYS="${2:-5}"
            shift 2
            ;;
        --manifest)
            MANIFEST_FILE="${2:-backup_manifest.tsv}"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

echo -e "DAY\tCHUNKS\tSTATUS" > "$MANIFEST_FILE"

# --- STEP 1: DEFINE SCOPED HELPER FUNCTIONS ---

# TODO: Define process_day_chunks() with strict 'local' variable scoping.
# Notice what happens if chunk_id or day is assigned globally!
process_day_chunks() {
    # TODO: Declare local variables
    day="$1"
    for day in 1 2 3; do
        :
    done
}

# TODO: Define archive_day() with strict 'local' variable scoping.
archive_day() {
    # TODO: Declare local variables
    day="$1"
    process_day_chunks "$day"
    echo -e "DAY_${day}\t3\tSUCCESS" >> "$MANIFEST_FILE"
}

# --- STEP 2: MAIN MULTI-DAY ORCHESTRATION LOOP ---
TOTAL_CHUNKS=0
day_id=1

while (( day_id <= TOTAL_DAYS )); do
    # TODO: Call archive_day with "$day_id"
    # Ensure day_id is not overwritten by inner functions!
    archive_day "$day_id"
    TOTAL_CHUNKS=$((TOTAL_CHUNKS + 3))
    (( ++day_id ))
done

# --- STEP 3: OUTPUT SUMMARY ---
echo "BACKUP_BOT_COMPLETE: days=$TOTAL_DAYS, total_chunks=$TOTAL_CHUNKS, manifest=$MANIFEST_FILE"
