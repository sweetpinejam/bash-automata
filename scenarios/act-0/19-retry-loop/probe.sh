#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.19: THE EXPONENTIAL BACKOFF RETRY LOOP
# ==============================================================================
# Resilient microservice readiness probe with exponential backoff and real curl.
#
# MISSION:
# 1. Enable defensive execution ('set -euo pipefail').
# 2. Accept parameters with safe fallbacks:
#    - TARGET_URL="${1:-${TARGET_URL:-http://127.0.0.1:8080/health}}"
#    - MAX_ATTEMPTS="${2:-${MAX_ATTEMPTS:-5}}"
# 3. Implement an exponential backoff polling loop:
#    - Track attempt counter (start at 1, loop while (( attempt <= MAX_ATTEMPTS )))
#    - Track delay (start at 1 second, double on failure: (( delay *= 2 )))
#    - Cap delay at MAX_DELAY=8: if (( delay > MAX_DELAY )); then delay="$MAX_DELAY"; fi
# 4. Probe the endpoint using real curl:
#    curl -s -f -m 2 "$TARGET_URL"
# 5. Log each attempt to './probe_attempts.log':
#    Format: attempt=<N> status=<SUCCESS|FAILURE> exit_code=<C> delay=<D> timestamp=<T>
# 6. On success:
#    - Write './probe_summary.json' (status: "SERVICE_READY")
#    - Print 'PROBE_SUCCESS: attempts=<N>, target=<URL>, status=READY'
#    - Exit 0
# 7. On timeout exhaustion:
#    - Write './probe_summary.json' (status: "TIMEOUT")
#    - Print 'PROBE_TIMEOUT: Exhausted <N> attempts against <URL>' to stderr
#    - Exit 1
# ==============================================================================

set -euo pipefail

TARGET_URL="${1:-${TARGET_URL:-http://127.0.0.1:8080/health}}"
MAX_ATTEMPTS="${2:-${MAX_ATTEMPTS:-5}}"
MAX_DELAY=8
LOG_FILE="./probe_attempts.log"

# BROKEN STARTER CODE:
# Naive single probe fails immediately if the upstream service is warming up!
echo "[-] Probing service at $TARGET_URL..."

# TODO: Replace this naive single check with a while retry loop:
if response=$(curl -s -f -m 2 "$TARGET_URL"); then
    echo "PROBE_SUCCESS: attempts=1, target=$TARGET_URL, status=READY"
    exit 0
else
    echo "PROBE_TIMEOUT: Single attempt failed" >&2
    exit 1
fi
