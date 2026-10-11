#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Ingestion Collector (Constant O(1) Memory Streaming)
# ==============================================================================
set -euo pipefail

output_file="processed.log"
rm -f "$output_file"

# O(1) Constant memory streaming pipeline:
# Writes directly to output stream without caching records in memory arrays
while IFS= read -r line; do
  echo "PROCESSED: $line"
done < feed.raw > "$output_file"

echo "INGEST_FINISHED"
