#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: High-Frequency Telemetry Writer (/dev/shm)
# ==============================================================================
set -euo pipefail

BUS_FILE="/dev/shm/telemetry_bus.dat"
trap 'rm -f "$BUS_FILE"' EXIT

for (( i=1; i<=100; i++ )); do
  echo "FRAME_$i load=0.55 temp=42C" > "$BUS_FILE"
  sleep 0.005
done

echo "WRITER_FINISHED"
