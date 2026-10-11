#!/usr/bin/env bash
# ==============================================================================
# Live Telemetry Pipeline
# Problem: grep buffers in 4KB blocks across pipes, causing multi-second delays!
# ==============================================================================
set -euo pipefail

output_file="events.stream"
rm -f "$output_file"

# BROKEN: Standard grep in a pipeline buffers its output in 4096-byte blocks!
# Downstream consumers receive nothing until hundreds of events accumulate!
bash producer.sh | grep "ALERT" > "$output_file"

echo "PIPELINE_COMPLETE"
