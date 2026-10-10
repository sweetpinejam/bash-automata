#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Automated Traffic Metrics Aggregator
# ==============================================================================
set -euo pipefail

total_count=0
error_count=0
total_latency=0

while read -r status_part latency_part; do
  [[ -n "$status_part" ]] || continue

  status="${status_part##*=}"
  latency="${latency_part##*=}"

  # Native in-memory arithmetic commands:
  # NOTE: Under 'set -e', avoid post-increment on 0 ('(( total_count++ ))') because
  # evaluating 0 returns exit status 1. Use '(( total_count += 1 ))' or '(( ++total_count ))'!
  (( total_count += 1 ))
  (( total_latency += latency ))

  if (( status >= 500 )); then
    (( error_count += 1 ))
  fi
done < samples.log

# Compute metrics using arithmetic expansion:
avg_latency=0
err_pct=0

if (( total_count > 0 )); then
  avg_latency=$(( total_latency / total_count ))
  err_pct=$(( (error_count * 100) / total_count ))
fi

cat <<EOF > summary.txt
TOTAL_COUNT=$total_count
AVG_LATENCY=$avg_latency
ERR_PCT=$err_pct
EOF

echo "METRICS_AGGREGATED"
