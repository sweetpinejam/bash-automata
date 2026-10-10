#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Security Event Log Classifier
# ==============================================================================
set -euo pipefail

output="threats.csv"
echo "IP,PORT,REASON" > "$output"

pattern='^ALERT[[:space:]]+ip=([0-9.]+)[[:space:]]+port=([0-9]+)[[:space:]]+reason=([A-Z_]+)'

while IFS= read -r line; do
  [[ -n "$line" ]] || continue

  # Native Bash Regex evaluation and capture:
  if [[ "$line" =~ $pattern ]]; then
    ip="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[2]}"
    reason="${BASH_REMATCH[3]}"
    echo "$ip,$port,$reason" >> "$output"
  fi
done < firewall.log

echo "CLASSIFICATION_COMPLETE"
