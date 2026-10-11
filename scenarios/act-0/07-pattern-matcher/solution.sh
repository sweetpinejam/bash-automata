#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.07 (Pattern Matcher)
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

pattern='^ALERT[[:space:]]+ts=([0-9]+)[[:space:]]+ip=([0-9.]+)[[:space:]]+port=([0-9]+)[[:space:]]+reason=([A-Z_]+)'

while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    (( ++TOTAL_EVALUATED ))

    if [[ "$line" =~ $pattern ]]; then
        (( ++THREATS_COUNT ))

        ts="${BASH_REMATCH[1]}"
        ip="${BASH_REMATCH[2]}"
        port="${BASH_REMATCH[3]}"
        reason="${BASH_REMATCH[4]}"

        # Severity classification
        case "$reason" in
            SQL_INJECTION|REMOTE_CODE_EXEC)
                severity="CRITICAL"
                (( ++CRITICAL_COUNT ))
                ;;
            BRUTE_FORCE_AUTH|PORT_SCAN)
                severity="HIGH"
                (( ++HIGH_COUNT ))
                ;;
            UNAUTHORIZED_ACCESS|RATE_LIMIT_EXCEEDED)
                severity="MEDIUM"
                (( ++MEDIUM_COUNT ))
                ;;
            *)
                severity="LOW"
                ;;
        esac

        # Scope classification
        if [[ "$ip" == 10.* || "$ip" == 192.168.* || "$ip" == 172.16.* ]]; then
            scope="INTERNAL"
        else
            scope="EXTERNAL"
            (( ++EXTERNAL_COUNT ))
        fi

        echo "$ts,$ip,$port,$severity,$reason,$scope" >> "$OUTPUT_CSV"
    fi
done < "$INPUT_LOG"

echo "CLASSIFIER_SUMMARY: evaluated=$TOTAL_EVALUATED, threats=$THREATS_COUNT, critical=$CRITICAL_COUNT, high=$HIGH_COUNT, medium=$MEDIUM_COUNT, external=$EXTERNAL_COUNT"
