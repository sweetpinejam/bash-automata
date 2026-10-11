#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Health Monitor Daemon
# ==============================================================================
set -euo pipefail

CYCLES="${1:-50}"
status_file="node.status"
summary_file="monitor.summary"
rm -f "$summary_file"

for (( i=1; i<=CYCLES; i++ )); do
  echo "health=OK cycle=$i load=0.12" > "$status_file"

  # Allocate dynamic descriptor
  exec {fd}< "$status_file"
  read -r line <&"$fd"
  echo "Cycle $i: $line" >> "$summary_file"

  # Explicitly close descriptor to prevent OS table exhaustion
  exec {fd}<&-
done

echo "MONITOR_RUN_COMPLETE"
