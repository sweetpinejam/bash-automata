#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.02 (Default Fallbacks & Guards)
# ==============================================================================
set -euo pipefail

OUTPUT_FILE=".env.runtime"

# --- STEP 1: PARSE ARGUMENTS ---
if [[ "${1:-}" == "--output" ]]; then
    OUTPUT_FILE="${2:-}"
    [[ -n "$OUTPUT_FILE" ]] || { echo "Error: Missing output file path" >&2; exit 1; }
    shift 2
fi

# --- STEP 2: APPLY FALLBACKS & MANDATORY GUARDS ---
PORT="${PORT:-8080}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-30}"

: "${API_SECRET:?API_SECRET is required}"
: "${CLUSTER_NAME:?CLUSTER_NAME is required}"

METRICS_ENABLED="${PROMETHEUS_ENDPOINT:+true}"
METRICS_ENABLED="${METRICS_ENABLED:-false}"

# --- STEP 3: NUMERIC VALIDATIONS ---
for p in "$PORT" "$DB_PORT"; do
    if ! [[ "$p" =~ ^[0-9]+$ ]] || (( p < 1024 || p > 65535 )); then
        echo "Error: Port '$p' must be an integer between 1024 and 65535" >&2
        exit 1
    fi
done

# --- STEP 4: WRITE OUTPUT CONFIG WITH SECURE PERMISSIONS ---
(
    umask 077
    cat <<EOF > "$OUTPUT_FILE"
PORT=$PORT
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
LOG_LEVEL=$LOG_LEVEL
TIMEOUT_SECONDS=$TIMEOUT_SECONDS
API_SECRET=$API_SECRET
CLUSTER_NAME=$CLUSTER_NAME
METRICS_ENABLED=$METRICS_ENABLED
EOF
)
chmod 600 "$OUTPUT_FILE"

# --- STEP 5: REDACTED CONSOLE LOGGING ---
declare -A CONFIG_VARS=(
    ["PORT"]="$PORT"
    ["DB_HOST"]="$DB_HOST"
    ["DB_PORT"]="$DB_PORT"
    ["LOG_LEVEL"]="$LOG_LEVEL"
    ["TIMEOUT_SECONDS"]="$TIMEOUT_SECONDS"
    ["API_SECRET"]="$API_SECRET"
    ["CLUSTER_NAME"]="$CLUSTER_NAME"
    ["METRICS_ENABLED"]="$METRICS_ENABLED"
)

VARS_COUNT=0
MASKED_COUNT=0

for key in PORT DB_HOST DB_PORT LOG_LEVEL TIMEOUT_SECONDS API_SECRET CLUSTER_NAME METRICS_ENABLED; do
    val="${CONFIG_VARS[$key]}"
    VARS_COUNT=$((VARS_COUNT + 1))
    if [[ "$key" == *SECRET* || "$key" == *KEY* || "$key" == *TOKEN* ]]; then
        echo "  [ENV] $key=***REDACTED***"
        MASKED_COUNT=$((MASKED_COUNT + 1))
    else
        echo "  [ENV] $key=$val"
    fi
done

# --- STEP 6: SUMMARY OUTPUT ---
echo "CONFIG_COMPILED: vars=$VARS_COUNT, masked=$MASKED_COUNT, output=$OUTPUT_FILE"
