#!/usr/bin/env bash
# ==============================================================================
# Security Event Log Classifier
# Goal: Filter ALERT logs and output threats.csv (IP,PORT,REASON)
# Constraint: Use native [[ $line =~ regex ]] and BASH_REMATCH (no grep, awk, cut)
# ==============================================================================
set -euo pipefail

output="threats.csv"
echo "IP,PORT,REASON" > "$output"

# Regex pattern matching ALERT lines:
# Group 1: IP address
# Group 2: Port
# Group 3: Reason
pattern='^ALERT[[:space:]]+ip=([0-9.]+)[[:space:]]+port=([0-9]+)[[:space:]]+reason=([A-Z_]+)'

while IFS= read -r line; do
  [[ -n "$line" ]] || continue

  # TODO: Test $line against $pattern using [[ $line =~ $pattern ]]:
  # Extract:
  #   ip="${BASH_REMATCH[1]}"
  #   port="${BASH_REMATCH[2]}"
  #   reason="${BASH_REMATCH[3]}"
  # Write: echo "$ip,$port,$reason" >> "$output"

  if false; then
    :
  fi
done < firewall.log

echo "CLASSIFICATION_COMPLETE"
