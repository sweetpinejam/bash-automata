#!/usr/bin/env bash
# ==============================================================================
# Upstream Gateway Caller (Production Subsystem Wrapper)
# ==============================================================================
# Incident: INCIDENT-1088
# When upstream RPC services hang or experience network partitions, synchronous
# callers block indefinitely, consuming worker threads and starving thread pools.
# The minimal execution container lacks the GNU coreutils 'timeout' binary.
#
# BROKEN STATE:
# Direct synchronous execution with no watchdog circuit breaker.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration Defaults
# ------------------------------------------------------------------------------
TIMEOUT_SEC=1
MODE="normal"
RPC_SCRIPT="upstream_rpc.py"
STATUS_FILE="status.json"
VERBOSE=0

# ------------------------------------------------------------------------------
# Logging Utilities
# ------------------------------------------------------------------------------
log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] $*" >&2
}

log_warn() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] $*" >&2
}

log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [ERROR] $*" >&2
}

# ------------------------------------------------------------------------------
# Telemetry Manifest
# ------------------------------------------------------------------------------
write_telemetry() {
    local status="$1"
    local exit_code="$2"
    local duration_ms="$3"

    cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "mode": "$MODE",
  "timeout_sec": $TIMEOUT_SEC,
  "status": "$status",
  "exit_code": $exit_code,
  "duration_ms": $duration_ms
}
EOF
}

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_SEC="$2"
            shift 2
            ;;
        --status-file)
            STATUS_FILE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        normal|hang)
            MODE="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--mode normal|hang] [--timeout SECONDS] [--status-file PATH]"
            exit 0
            ;;
        *)
            log_warn "Unknown argument ignored: $1"
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Execution & Invocation
# ------------------------------------------------------------------------------
log_info "Initializing API Gateway Caller (PID: $$, Mode: $MODE, Timeout: ${TIMEOUT_SEC}s)..."

cmd=("python3" "$RPC_SCRIPT")
if [[ "$MODE" == "hang" ]]; then
    cmd+=("--hang")
fi

t_start=$(date +%s)

# ==============================================================================
# BUG: Naive synchronous invocation blocks forever when upstream hangs!
# Minimal Alpine / distroless environments lack 'timeout', causing total hang.
# TODO: Implement a pure Bash watchdog wrapper 'run_with_timeout'.
# ==============================================================================
log_info "Executing upstream RPC invocation synchronously (UNPROTECTED)..."
"${cmd[@]}"

t_end=$(date +%s)
duration_ms=$(( (t_end - t_start) * 1000 ))

write_telemetry "SUCCESS" 0 "$duration_ms"
log_info "Upstream RPC completed successfully."
echo "CALL_SUCCESSFUL"
exit 0
