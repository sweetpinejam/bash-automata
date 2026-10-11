#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.06 (Integer Arithmetic)
# ==============================================================================
set -euo pipefail

INPUT_LOG="${1:-samples.log}"

[[ -f "$INPUT_LOG" ]] || { echo "Error: Input file '$INPUT_LOG' not found" >&2; exit 1; }

TOTAL_REQS=0
COUNT_2XX=0
COUNT_3XX=0
COUNT_4XX=0
COUNT_5XX=0
TOTAL_LATENCY=0
MIN_LATENCY=999999
MAX_LATENCY=0
TOTAL_BYTES=0
FAST_REQS=0

# Step 1: Parse and accumulate
while read -r ts_part method_part status_part latency_part bytes_part; do
    [[ -n "$status_part" ]] || continue

    status="${status_part##*=}"
    latency="${latency_part##*=}"
    bytes="${bytes_part##*=}"

    (( ++TOTAL_REQS ))
    (( TOTAL_LATENCY += latency ))
    (( TOTAL_BYTES += bytes ))

    (( latency < MIN_LATENCY )) && MIN_LATENCY=$latency
    (( latency > MAX_LATENCY )) && MAX_LATENCY=$latency
    (( latency <= 200 )) && (( ++FAST_REQS ))

    if (( status >= 200 && status < 300 )); then
        (( ++COUNT_2XX ))
    elif (( status >= 300 && status < 400 )); then
        (( ++COUNT_3XX ))
    elif (( status >= 400 && status < 500 )); then
        (( ++COUNT_4XX ))
    elif (( status >= 500 )); then
        (( ++COUNT_5XX ))
    fi
done < "$INPUT_LOG"

[[ "$TOTAL_REQS" -gt 0 ]] || { echo "Error: No samples processed" >&2; exit 1; }

# Step 2: Compute aggregate metrics
AVG_LATENCY=$(( TOTAL_LATENCY / TOTAL_REQS ))
SLA_PCT=$(( (FAST_REQS * 100) / TOTAL_REQS ))
ERR_PCT=$(( (COUNT_5XX * 100) / TOTAL_REQS ))

# Step 3: Determine SLA verdict
if (( COUNT_5XX > 0 && ERR_PCT >= 5 )); then
    VERDICT="SLA_BREACH_HIGH_ERRORS"
elif (( AVG_LATENCY > 300 )); then
    VERDICT="SLA_BREACH_HIGH_LATENCY"
else
    VERDICT="HEALTHY_SLA_MET"
fi

# Step 4: Emit rollup TSV
cat <<EOF > "metrics_rollup.tsv"
METRIC	VALUE
TOTAL_REQS	$TOTAL_REQS
COUNT_2XX	$COUNT_2XX
COUNT_3XX	$COUNT_3XX
COUNT_4XX	$COUNT_4XX
COUNT_5XX	$COUNT_5XX
AVG_LATENCY	$AVG_LATENCY
MIN_LATENCY	$MIN_LATENCY
MAX_LATENCY	$MAX_LATENCY
TOTAL_BYTES	$TOTAL_BYTES
SLA_COMPLIANCE	$SLA_PCT
ERROR_PERCENT	$ERR_PCT
SLA_VERDICT	$VERDICT
EOF

# Step 5: Output summary
echo "AGGREGATOR_SUMMARY: reqs=$TOTAL_REQS, avg_latency=${AVG_LATENCY}ms, min=${MIN_LATENCY}ms, max=${MAX_LATENCY}ms, err_pct=${ERR_PCT}%, sla=${SLA_PCT}%, verdict=$VERDICT"
