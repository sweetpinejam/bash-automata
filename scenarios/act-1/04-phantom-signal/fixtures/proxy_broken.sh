#!/usr/bin/env bash
# ==============================================================================
# Proxy Daemon
# Problem: Lacks signal traps for SIGHUP and SIGUSR1!
# ==============================================================================
set -euo pipefail

log_file="proxy.log"
echo "$$" > proxy.pid
echo "PROXY_STARTED" > "$log_file"

source app.conf

# In the broken version, neither HUP nor USR1 is trapped.
# When SIGHUP arrives, default OS behavior terminates the process!

running=true
requests_handled=0

while $running; do
  (( requests_handled += 1 ))
  sleep 0.1 &
  wait $! 2>/dev/null || true
done
