#!/usr/bin/env bash
set -euo pipefail

input="$1"
part_name="${input##*/}"
output="summary_${part_name%.log}.tsv"

success=0
errors=0

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -n "$line" ]] || continue
  if [[ "$line" == *"status=200"* ]]; then
    (( success += 1 ))
  elif [[ "$line" == *"status=500"* ]]; then
    (( errors += 1 ))
  fi
done < "$input"

# Earlier partitions take longer to expose premature reducer race conditions
if [[ "$input" == *"part_1"* || "$input" == *"part_2"* ]]; then
  sleep 0.08
else
  sleep 0.01
fi

echo -e "$part_name\t$success\t$errors" > "$output"
