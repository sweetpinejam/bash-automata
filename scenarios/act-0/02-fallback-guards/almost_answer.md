# Code Blueprint & Almost-Answer: Default Fallbacks & Guards

If you need structural syntax guidance to complete `env_injector.sh`:

### 1. Default Fallbacks & Mandatory Assertions
```bash
PORT="${PORT:-8080}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-30}"

# Mandatory checks: aborts immediately with error message if unset or empty
: "${API_SECRET:?API_SECRET is required}"
: "${CLUSTER_NAME:?CLUSTER_NAME is required}"

# Alternate substitution
METRICS_ENABLED="${PROMETHEUS_ENDPOINT:+true}"
METRICS_ENABLED="${METRICS_ENABLED:-false}"
```

### 2. Numeric Range Validation
```bash
for p in "$PORT" "$DB_PORT"; do
    if ! [[ "$p" =~ ^[0-9]+$ ]] || (( p < 1024 || p > 65535 )); then
        echo "Error: Invalid port $p" >&2
        exit 1
    fi
done
```

### 3. Redacted Secret Logging
```bash
if [[ "$key" == *SECRET* || "$key" == *KEY* || "$key" == *TOKEN* ]]; then
    echo "  [ENV] $key=***REDACTED***"
    MASKED_COUNT=$((MASKED_COUNT + 1))
else
    echo "  [ENV] $key=$val"
fi
```
