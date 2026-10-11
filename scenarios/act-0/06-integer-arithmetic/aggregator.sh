#!/usr/bin/env bash
# ==============================================================================
# Automated Traffic Metrics Aggregator
# Goal: Compute total count, average latency, and error percentage in pure Bash
# Constraint: Use native (( ... )) and $(( ... )) (no expr, bc, awk)
# ==============================================================================
set -euo pipefail

total_count=0
error_count=0
total_latency=0

while read -r status_part latency_part; do
  [[ -n "$status_part" ]] || continue

  # Extract values
  status="${status_part##*=}"
  latency="${latency_part##*=}"

  # TODO: Refactor arithmetic increments using native Bash builtins:
  # 1. Increment total_count by 1
  # 2. Add latency to total_latency
  # 3. If status is >= 500, increment error_count by 1
  total_count=$(expr $total_count + 1)
  total_latency=$(expr $total_latency + $latency)
  if [ $status -ge 500 ]; then
    error_count=$(expr $error_count + 1)
  fi
done < samples.log

# TODO: Compute average latency and error percentage using $(( ... )):
# avg_latency = total_latency / total_count
# err_pct = (error_count * 100) / total_count
avg_latency=0
err_pct=0

cat <<EOF > summary.txt
TOTAL_COUNT=$total_count
AVG_LATENCY=$avg_latency
ERR_PCT=$err_pct
EOF

echo "METRICS_AGGREGATED"
