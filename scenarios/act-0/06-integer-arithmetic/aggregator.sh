#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.06: Integer Arithmetic (High-Throughput Traffic & SLA Aggregator)
# ==============================================================================
# INSTRUCTIONS:
# Implement a pure Bash traffic metrics aggregator.
#
# HARD CONSTRAINT:
# Strictly NO external arithmetic tools: expr, bc, awk, dc, python, perl.
# All math MUST use native '(( ... ))' and '$(( ... ))'.
#
# Log format:
#   timestamp=<ts> method=<m> status=<s> latency_ms=<l> size_bytes=<b>
#
# Requirements:
# 1. Positional argument $1 = log file (default: "samples.log").
# 2. Extract fields in pure Bash memory.
# 3. Accumulate:
#    - TOTAL_REQS
#    - Status counters: COUNT_2XX, COUNT_3XX, COUNT_4XX, COUNT_5XX
#    - TOTAL_LATENCY, MIN_LATENCY, MAX_LATENCY
#    - TOTAL_BYTES
#    - FAST_REQS (requests with latency_ms <= 200)
# 4. Compute metrics via $(( ... )):
#    - AVG_LATENCY = TOTAL_LATENCY / TOTAL_REQS
#    - SLA_PCT = (FAST_REQS * 100) / TOTAL_REQS
#    - ERR_PCT = (COUNT_5XX * 100) / TOTAL_REQS
# 5. SLA Verdict:
#    - If COUNT_5XX > 0 && ERR_PCT >= 5 -> "SLA_BREACH_HIGH_ERRORS"
#    - Else if AVG_LATENCY > 300        -> "SLA_BREACH_HIGH_LATENCY"
#    - Else                              -> "HEALTHY_SLA_MET"
# 6. Generate "metrics_rollup.tsv" with tab-separated key-values.
# 7. Print summary:
#    "AGGREGATOR_SUMMARY: reqs=<N>, avg_latency=<A>ms, min=<Min>ms, max=<Max>ms, err_pct=<E>%, sla=<S>%, verdict=<V>"
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

# --- STEP 1: PARSE AND ACCUMULATE IN PURE BASH ---
while read -r ts_part method_part status_part latency_part bytes_part; do
    [[ -n "$status_part" ]] || continue

    status="${status_part##*=}"
    latency="${latency_part##*=}"
    bytes="${bytes_part##*=}"

    # TODO: Accumulate metrics using pure arithmetic '(( ... ))'.
    # Watch out for the set -e trap on (( var++ ))! Use (( ++var )) or (( var += 1 )).
    # 1. Increment TOTAL_REQS
    # 2. Add latency to TOTAL_LATENCY
    # 3. Add bytes to TOTAL_BYTES
    # 4. Update MIN_LATENCY and MAX_LATENCY
    # 5. Increment FAST_REQS if latency <= 200
    # 6. Increment appropriate status counter (2xx, 3xx, 4xx, 5xx)

done < "$INPUT_LOG"

[[ "$TOTAL_REQS" -gt 0 ]] || { echo "Error: No samples processed" >&2; exit 1; }

# --- STEP 2: COMPUTE AGGREGATE METRICS VIA $(( ... )) ---
# TODO: Calculate AVG_LATENCY, SLA_PCT, and ERR_PCT using integer division.
AVG_LATENCY=0
SLA_PCT=0
ERR_PCT=0

# --- STEP 3: DETERMINE OPERATIONAL SLA VERDICT ---
# TODO: Evaluate SLA criteria using (( ... )):
VERDICT="UNKNOWN"


# --- STEP 4: EMIT ROLLUP FILE ---
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

# --- STEP 5: OUTPUT SUMMARY METRICS ---
echo "AGGREGATOR_SUMMARY: reqs=$TOTAL_REQS, avg_latency=${AVG_LATENCY}ms, min=${MIN_LATENCY}ms, max=${MAX_LATENCY}ms, err_pct=${ERR_PCT}%, sla=${SLA_PCT}%, verdict=$VERDICT"
