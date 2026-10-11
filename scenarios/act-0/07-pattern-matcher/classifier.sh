#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.07: Pattern Matcher (Security Incident & Threat Classifier)
# ==============================================================================
# INSTRUCTIONS:
# Implement a pure Bash security event classifier and threat filter.
#
# HARD CONSTRAINT:
# Strictly NO external text processing binaries: grep, awk, cut, sed, python, perl.
# All parsing MUST use native '[[ $line =~ $regex ]]' with 'BASH_REMATCH',
# and native glob matching '[[ $ip == 10.* ]]'.
#
# Log format:
#   ALERT ts=<timestamp> ip=<ip> port=<port> reason=<reason>
#   (Plus benign logs: NOTICE, INFO, WARN)
#
# Requirements:
# 1. Positional arguments:
#    $1 = input log file (default: "firewall.log")
#    $2 = output CSV file (default: "threats.csv")
# 2. Extract fields using native regex and BASH_REMATCH:
#    - TIMESTAMP
#    - IP
#    - PORT
#    - REASON
# 3. Classify SEVERITY:
#    - SQL_INJECTION or REMOTE_CODE_EXEC    -> "CRITICAL"
#    - BRUTE_FORCE_AUTH or PORT_SCAN        -> "HIGH"
#    - UNAUTHORIZED_ACCESS or RATE_LIMIT_EXCEEDED -> "MEDIUM"
#    - Any other reason                     -> "LOW"
# 4. Classify SCOPE using glob matching:
#    - If IP matches 10.*, 192.168.*, or 172.16.* -> "INTERNAL"
#    - Else                                        -> "EXTERNAL"
# 5. Write records to CSV:
#    TIMESTAMP,IP,PORT,SEVERITY,REASON,SCOPE
# 6. Print summary:
#    "CLASSIFIER_SUMMARY: evaluated=<N>, threats=<T>, critical=<C>, high=<H>, medium=<M>, external=<E>"
# ==============================================================================
set -euo pipefail

INPUT_LOG="${1:-firewall.log}"
OUTPUT_CSV="${2:-threats.csv}"

[[ -f "$INPUT_LOG" ]] || { echo "Error: Input file '$INPUT_LOG' not found" >&2; exit 1; }

echo "TIMESTAMP,IP,PORT,SEVERITY,REASON,SCOPE" > "$OUTPUT_CSV"

TOTAL_EVALUATED=0
THREATS_COUNT=0
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
EXTERNAL_COUNT=0

# Define regex pattern (store in variable unquoted on right side of =~):
pattern='^ALERT[[:space:]]+ts=([0-9]+)[[:space:]]+ip=([0-9.]+)[[:space:]]+port=([0-9]+)[[:space:]]+reason=([A-Z_]+)'

# --- STEP 1: STREAM EVALUATION LOOP ---
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    TOTAL_EVALUATED=$((TOTAL_EVALUATED + 1))

    # TODO: Check if $line matches $pattern using [[ $line =~ $pattern ]].
    # If it does NOT match, continue.
    # If it matches:
    # 1. Increment THREATS_COUNT
    # 2. Extract timestamp, ip, port, and reason from BASH_REMATCH
    # 3. Determine SEVERITY (CRITICAL, HIGH, MEDIUM, LOW)
    #    - Update CRITICAL_COUNT, HIGH_COUNT, MEDIUM_COUNT
    # 4. Determine SCOPE (INTERNAL vs EXTERNAL) using glob matching
    #    - Update EXTERNAL_COUNT if external
    # 5. Append row to "$OUTPUT_CSV"

done < "$INPUT_LOG"

# --- STEP 2: SUMMARY METRICS ---
echo "CLASSIFIER_SUMMARY: evaluated=$TOTAL_EVALUATED, threats=$THREATS_COUNT, critical=$CRITICAL_COUNT, high=$HIGH_COUNT, medium=$MEDIUM_COUNT, external=$EXTERNAL_COUNT"
