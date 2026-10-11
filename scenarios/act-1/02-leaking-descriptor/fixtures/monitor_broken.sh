#!/usr/bin/env bash
# ==============================================================================
# Health Monitor Daemon
# Problem: Dynamically allocates file descriptors but forgets to close them!
# ==============================================================================
set -euo pipefail

CYCLES="${1:-50}"
status_file="node.status"
summary_file="monitor.summary"
rm -f "$summary_file"

for (( i=1; i<=CYCLES; i++ )); do
  echo "health=OK cycle=$i load=0.12" > "$status_file"

  # Dynamic FD allocation: Bash assigns an available descriptor (10, 11, 12...)
  # BUG: Never closes $fd, causing descriptor exhaustion ('Too many open files')!
  exec {fd}< "$status_file"
  read -r line <&"$fd"
  echo "Cycle $i: $line" >> "$summary_file"

  # TODO: Explicitly close the allocated file descriptor before the next iteration
done

echo "MONITOR_RUN_COMPLETE"
