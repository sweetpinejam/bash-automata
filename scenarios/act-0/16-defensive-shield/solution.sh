#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.16 (The Defensive Shield)
# ==============================================================================
# Hardened deployment runner with defensive flags and ERR crash traps.
# ==============================================================================

# Step 1: Enable strict defensive execution
set -euo pipefail

# ------------------------------------------------------------------------------
# Step 2 & 3: Crash Diagnostic Trap
# ------------------------------------------------------------------------------
on_failure() {
    local line_num="$1"
    local command="$2"
    local code="$3"

    echo "🚨 DEPLOYMENT CRASH DETECTED at line $line_num (command: '$command', exit: $code)" >&2

    cat <<EOF > "deploy_crash.dump"
CRASH_LINE=$line_num
FAILED_COMMAND=$command
EXIT_CODE=$code
TIMESTAMP=$(date +%s)
EOF
}

trap 'on_failure "$LINENO" "$BASH_COMMAND" "$?"' ERR

# ------------------------------------------------------------------------------
# Step 4: Configuration & Unbound Variable Validation
# ------------------------------------------------------------------------------
DEPLOY_ENV="${1:-$DEPLOY_ENV}"
RELEASE_TAG="${2:-$RELEASE_TAG}"
SIMULATE_FAILURE="${SIMULATE_FAILURE:-none}"

for arg in "$@"; do
    if [[ "$arg" == "--simulate-pipe-fail" ]]; then
        SIMULATE_FAILURE="pipefail"
    elif [[ "$arg" == "--simulate-crash" ]]; then
        SIMULATE_FAILURE="crash"
    fi
done

# ------------------------------------------------------------------------------
# Stage 1: Target Environment Validation
# ------------------------------------------------------------------------------
echo "[-] Stage 1: Validating deployment target ($DEPLOY_ENV)..."
case "$DEPLOY_ENV" in
    staging|production|canary|qa)
        ;;
    *)
        echo "Error: Invalid environment '$DEPLOY_ENV'. Must be staging|production|canary|qa." >&2
        exit 1
        ;;
esac

# ------------------------------------------------------------------------------
# Stage 2: Pipeline Integrity Verification
# ------------------------------------------------------------------------------
echo "[-] Stage 2: Verifying pipeline dependencies..."

if [[ "$SIMULATE_FAILURE" == "pipefail" ]]; then
    echo "[!] Simulating upstream pipeline crash..."
    false | tr 'a-z' 'A-Z' | grep -v "error"
fi

if [[ "$SIMULATE_FAILURE" == "crash" ]]; then
    echo "[!] Simulating critical step crash..."
    /bin/false
fi

# Standard pipeline check
printf "%s\n" "service:auth" "service:api" "service:db" | grep "^service:" | sort > /dev/null

# ------------------------------------------------------------------------------
# Stage 3: Rollout & Status Emission
# ------------------------------------------------------------------------------
echo "[-] Stage 3: Rollout release $RELEASE_TAG to $DEPLOY_ENV..."

cat <<EOF > "deploy_status.json"
{
  "status": "SUCCESS",
  "environment": "$DEPLOY_ENV",
  "tag": "$RELEASE_TAG",
  "defensive_shield": true,
  "timestamp": $(date +%s)
}
EOF

echo "DEPLOY_HARDENED: env=$DEPLOY_ENV, tag=$RELEASE_TAG, crash_trap=ACTIVE, status=SUCCESS"
