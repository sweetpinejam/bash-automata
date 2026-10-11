#!/usr/bin/env bash
# ==============================================================================
# Ingestion Collector
# Problem: Loads all 5,000 records into a shell array, bloating memory!
# ==============================================================================
set -euo pipefail

output_file="processed.log"
rm -f "$output_file"

# BROKEN / MEMORY BLOAT:
# Reading an unbounded dataset into a shell array creates massive memory overhead!
# Bash array allocations can easily bloat to tens of megabytes, triggering OOM!
declare -a records
while IFS= read -r line; do
  records+=("$line")
done < feed.raw

# Flush array to disk
for item in "${records[@]}"; do
  echo "PROCESSED: $item" >> "$output_file"
done

echo "INGEST_FINISHED"
