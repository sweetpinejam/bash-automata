#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.19 (The Exponential Backoff Retry Loop)
# ==============================================================================
# Resilient microservice readiness probe with exponential backoff and real curl.
# ==============================================================================

set -euo pipefail

TARGET_URL="${1:-${TARGET_URL:-http://127.0.0.1:8080/health}}"
MAX_ATTEMPTS="${2:-${MAX_ATTEMPTS:-5}}"
MAX_DELAY="${MAX_DELAY:-8}"
LOG_FILE="./probe_attempts.log"

attempt=1
delay="${BASE_DELAY:-1}"

echo "[-] Starting exponential backoff probe against: $TARGET_URL (max_attempts: $MAX_ATTEMPTS)"
> "$LOG_FILE"

while (( attempt <= MAX_ATTEMPTS )); do
    response=""
    if response=$(curl -s -f -m 2 "$TARGET_URL"); then
        echo "SERVICE_READY (attempt: $attempt, response: $response)"
        echo "attempt=$attempt status=SUCCESS exit_code=0 delay=0 timestamp=$(date +%s)" >> "$LOG_FILE"

        cat <<EOF > "./probe_summary.json"
{
  "status": "SERVICE_READY",
  "target_url": "$TARGET_URL",
  "total_attempts": $attempt,
  "response": ${response:-"{}"},
  "completed_at": $(date +%s)
}
EOF
        echo "PROBE_SUCCESS: attempts=$attempt, target=$TARGET_URL, status=READY"
        exit 0
    else
        curl_exit=$?
        echo "Attempt $attempt failed (exit: $curl_exit). Backing off for ${delay}s..." >&2
        echo "attempt=$attempt status=FAILURE exit_code=$curl_exit delay=$delay timestamp=$(date +%s)" >> "$LOG_FILE"

        if (( attempt == MAX_ATTEMPTS )); then
            break
        fi

        sleep "$delay"
        attempt=$(( attempt + 1 ))
        delay=$(( delay * 2 ))
        if (( delay > MAX_DELAY )); then
            delay="$MAX_DELAY"
        fi
    fi
done

echo "PROBE_TIMEOUT: Exhausted $MAX_ATTEMPTS attempts against $TARGET_URL" >&2

cat <<EOF > "./probe_summary.json"
{
  "status": "TIMEOUT",
  "target_url": "$TARGET_URL",
  "total_attempts": $MAX_ATTEMPTS,
  "completed_at": $(date +%s)
}
EOF

exit 1
