#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.04 (The Phantom Signal)
# ==============================================================================
# Zero-downtime proxy daemon with SIGHUP hot reloads and SIGUSR1 telemetry dumps.
# ==============================================================================

set -euo pipefail

CONF_FILE="app.conf"
LOG_FILE="proxy.log"
PID_FILE="proxy.pid"
METRICS_FILE="metrics.dump"

log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] $*" >> "$LOG_FILE"
}

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONF_FILE="$2"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --pid-file)
            PID_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo "$$" > "$PID_FILE"
echo "PROXY_STARTED" > "$LOG_FILE"
log_info "Proxy daemon booted successfully (PID: $$)"

# Initial configuration load
source "$CONF_FILE"

# ------------------------------------------------------------------------------
# Signal Handlers
# ------------------------------------------------------------------------------
reload_config() {
    source "$CONF_FILE"
    echo "CONFIG_RELOADED: BACKEND=$BACKEND" >> "$LOG_FILE"
}

dump_metrics() {
    echo "REQUESTS_HANDLED=$requests_handled BACKEND=$BACKEND" > "$METRICS_FILE"
}

terminate_daemon() {
    running=false
    rm -f "$PID_FILE"
}

# Bind signal traps
trap reload_config HUP
trap dump_metrics USR1
trap terminate_daemon TERM INT EXIT

running=true
requests_handled=0

# Responsive daemon event loop
while $running; do
    (( requests_handled += 1 ))

    # Background sleep + wait allows immediate signal interruption without stalls
    sleep 0.1 &
    wait $! 2>/dev/null || true
done

log_info "Proxy daemon exiting cleanly."
