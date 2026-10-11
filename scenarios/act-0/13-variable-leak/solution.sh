#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.13 (The Variable Leak)
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

printf "DAY\tCHUNKS\tSTATUS\n" > "$MANIFEST_FILE"

process_day_chunks() {
    local day="$1"
    local chunk_id

    for chunk_id in 1 2 3; do
        # Simulated chunk compression
        :
    done
}

archive_day() {
    local day="$1"
    local chunks_count=3

    process_day_chunks "$day"
    printf "DAY_%d\t%d\tSUCCESS\n" "$day" "$chunks_count" >> "$MANIFEST_FILE"
}

TOTAL_CHUNKS=0
day_id=1

while (( day_id <= TOTAL_DAYS )); do
    archive_day "$day_id"
    (( TOTAL_CHUNKS += 3 ))
    (( ++day_id ))
done

echo "BACKUP_BOT_COMPLETE: days=$TOTAL_DAYS, total_chunks=$TOTAL_CHUNKS, manifest=$MANIFEST_FILE"
