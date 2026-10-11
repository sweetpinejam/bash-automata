#!/usr/bin/env bash
# ==============================================================================
# High-Frequency Telemetry Writer
# Problem: Writes to slow disk directory instead of kernel shared memory!
# ==============================================================================
set -euo pipefail

# BROKEN: Writing to workspace disk path incurs physical storage latency
BUS_FILE="disk_telemetry.dat"

# TODO: Relocate high-frequency telemetry buffer to Linux shared memory (tmpfs)
# and ensure the memory buffer is cleanly unlinked on script termination.

for (( i=1; i<=100; i++ )); do
  echo "FRAME_$i load=0.55 temp=42C" > "$BUS_FILE"
  sleep 0.005
done

echo "WRITER_FINISHED"
