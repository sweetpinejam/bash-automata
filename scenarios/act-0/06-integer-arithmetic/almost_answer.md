# Code Blueprint & Almost-Answer: Integer Arithmetic

If you need arithmetic syntax templates for `aggregator.sh`:

### 1. In-Place Arithmetic Accumulation `(( ... ))`
```bash
# Safe increment under set -e
(( ++TOTAL_REQS ))

# Accumulating sums
(( TOTAL_LATENCY += latency ))
(( TOTAL_BYTES += bytes ))

# Min / Max tracking
(( latency < MIN_LATENCY )) && MIN_LATENCY=$latency
(( latency > MAX_LATENCY )) && MAX_LATENCY=$latency

# Status code bucketing
if (( status >= 200 && status < 300 )); then
    (( ++COUNT_2XX ))
elif (( status >= 500 )); then
    (( ++COUNT_5XX ))
fi
```

### 2. Computing Integer Ratios with `$(( ... ))`
```bash
AVG_LATENCY=$(( TOTAL_LATENCY / TOTAL_REQS ))
SLA_PCT=$(( (FAST_REQS * 100) / TOTAL_REQS ))
ERR_PCT=$(( (COUNT_5XX * 100) / TOTAL_REQS ))
```

### 3. Evaluating SLA Status with `(( ... ))`
```bash
if (( COUNT_5XX > 0 && ERR_PCT >= 5 )); then
    VERDICT="SLA_BREACH_HIGH_ERRORS"
elif (( AVG_LATENCY > 300 )); then
    VERDICT="SLA_BREACH_HIGH_LATENCY"
else
    VERDICT="HEALTHY_SLA_MET"
fi
```
