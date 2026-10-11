#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Live Telemetry Pipeline (Line-buffered)
# ==============================================================================
set -euo pipefail

output_file="events.stream"
rm -f "$output_file"

# Use --line-buffered or stdbuf -oL to force immediate flushing per line:
bash producer.sh | grep --line-buffered "ALERT" > "$output_file"

echo "PIPELINE_COMPLETE"
