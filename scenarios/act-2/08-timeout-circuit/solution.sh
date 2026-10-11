#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 2.08 (The Cascading Timeout Shield)
# ==============================================================================
# Pure Bash watchdog timer circuit breaker without external GNU 'timeout' utility.
# Implements dual-subshell concurrency, signal escalation (SIGTERM -> SIGKILL),
# early timer cancellation, and standard POSIX exit code 124.
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
# Pure Bash Timeout Wrapper Function
# ------------------------------------------------------------------------------
run_with_timeout() {
    local timeout_sec="$1"
    shift

    log_info "Spawning target process in background subshell..."
    "$@" &
    local cmd_pid=$!

    log_info "Arming watchdog timer subshell (limit: ${timeout_sec}s, target PID: $cmd_pid)..."
    (
        sleep "$timeout_sec"
        log_warn "Watchdog timer expired (${timeout_sec}s)! Escalating signals to PID $cmd_pid..."
        if kill -0 "$cmd_pid" 2>/dev/null; then
            kill -TERM "$cmd_pid" 2>/dev/null || true
            sleep 0.2
            if kill -0 "$cmd_pid" 2>/dev/null; then
                kill -KILL "$cmd_pid" 2>/dev/null || true
            fi
        fi
    ) &
    local timer_pid=$!

    local cmd_exit=0
    if wait "$cmd_pid" 2>/dev/null; then
        cmd_exit=0
    else
        cmd_exit=$?
    fi

    # Inspect whether timer was still actively sleeping
    if kill -0 "$timer_pid" 2>/dev/null; then
        log_info "Target completed before watchdog expired. Reaping timer subshell..."
        pkill -P "$timer_pid" 2>/dev/null || true
        kill "$timer_pid" 2>/dev/null || true
        wait "$timer_pid" 2>/dev/null || true
        return "$cmd_exit"
    else
        log_warn "Watchdog timer triggered interruption. Reaping watchdog subshell..."
        wait "$timer_pid" 2>/dev/null || true
        return 124
    fi
}

# ------------------------------------------------------------------------------
# Execution & Invocation
# ------------------------------------------------------------------------------
log_info "Initializing API Gateway Caller (PID: $$, Mode: $MODE, Timeout: ${TIMEOUT_SEC}s)..."

cmd=("python3" "$RPC_SCRIPT")
if [[ "$MODE" == "hang" ]]; then
    cmd+=("--hang")
fi

t_start=$(date +%s)

if run_with_timeout "$TIMEOUT_SEC" "${cmd[@]}"; then
    t_end=$(date +%s)
    duration_ms=$(( (t_end - t_start) * 1000 ))
    write_telemetry "SUCCESS" 0 "$duration_ms"
    log_info "Upstream RPC invocation completed successfully."
    echo "CALL_SUCCESSFUL"
    exit 0
else
    rc=$?
    t_end=$(date +%s)
    duration_ms=$(( (t_end - t_start) * 1000 ))
    write_telemetry "TIMEOUT_EXCEEDED" "$rc" "$duration_ms"
    log_error "TIMEOUT_INTERRUPTED: Upstream call exceeded ${TIMEOUT_SEC}s threshold (exit code $rc)."
    echo "TIMEOUT_INTERRUPTED"
    exit "$rc"
fi
