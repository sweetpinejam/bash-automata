#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Proxy Daemon with Signal Handling
# ==============================================================================
set -euo pipefail

log_file="proxy.log"
echo "$$" > proxy.pid
echo "PROXY_STARTED" > "$log_file"

source app.conf

reload_config() {
  source app.conf
  echo "CONFIG_RELOADED: BACKEND=$BACKEND" >> "$log_file"
}

dump_metrics() {
  echo "REQUESTS_HANDLED=$requests_handled BACKEND=$BACKEND" > metrics.dump
}

terminate_daemon() {
  running=false
}

# Trap SIGHUP for reload, SIGUSR1 for metrics, SIGTERM/INT for clean shutdown
trap reload_config HUP
trap dump_metrics USR1
trap terminate_daemon TERM INT EXIT

running=true
requests_handled=0

while $running; do
  (( requests_handled += 1 ))
  sleep 0.1 &
  wait $! 2>/dev/null || true
done

echo "PROXY_TERMINATED_CLEANLY" >> "$log_file"
