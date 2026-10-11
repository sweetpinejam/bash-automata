#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.04: THE PHANTOM SIGNAL (Zero-Downtime Infrastructure Proxy)
# ==============================================================================
# Enterprise proxy daemon supporting dynamic reloads and telemetry reporting.
#
# CRISIS:
# When automated deployers send 'kill -HUP $PID' to reload 'app.conf', the daemon
# abruptly crashes because SIGHUP is untrapped (default action: terminate process).
# Telemetry scrapers sending 'kill -USR1 $PID' are similarly ignored or killed.
#
# MISSION:
# 1. Bind 'reload_config()' to SIGHUP: re-source 'app.conf' and log CONFIG_RELOADED.
# 2. Bind 'dump_metrics()' to SIGUSR1: write metrics to 'metrics.dump'.
# 3. Bind 'terminate_daemon()' to SIGTERM, SIGINT, and EXIT for clean teardown.
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
# BROKEN STATE: Missing Signal Handlers
# ------------------------------------------------------------------------------
# 💥 THE BUG:
# By default, SIGHUP and SIGUSR1 terminate unhandled processes.
#
# TODO: Implement signal handler functions:
# 1. reload_config():
#    source "$CONF_FILE"
#    echo "CONFIG_RELOADED: BACKEND=$BACKEND" >> "$LOG_FILE"
#
# 2. dump_metrics():
#    echo "REQUESTS_HANDLED=$requests_handled BACKEND=$BACKEND" > "$METRICS_FILE"
#
# 3. terminate_daemon():
#    running=false
#
# 4. Register traps:
#    trap reload_config HUP
#    trap dump_metrics USR1
#    trap terminate_daemon TERM INT EXIT

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
rm -f "$PID_FILE"
