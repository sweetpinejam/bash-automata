#!/usr/bin/env bash
# ==============================================================================
# Automated Multi-Day Backup Bot
# Problem: Loop terminates prematurely after Day 1 due to global scope pollution!
# ==============================================================================
set -euo pipefail

report_file="backup_report.txt"
rm -f "$report_file"

# Helper function to process chunks
process_backup_day() {
  # TODO: Declare local variables using 'local' so they don't overwrite outer scope:
  # local day_id chunk
  day_id="$1"
  for day_id in {10..12}; do
    echo "  Processing chunk $day_id" >/dev/null
  done
}

day_id=1
while (( day_id <= 5 )); do
  echo "DAY_$day_id: SUCCESS" >> "$report_file"
  process_backup_day "$day_id"
  (( day_id += 1 ))
done

echo "ALL_BACKUPS_COMPLETE"
