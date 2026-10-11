#!/usr/bin/env bash
# ==============================================================================
# Upstream Gateway Caller
# Incident: When upstream_rpc hangs, this script blocks forever, exhausting
# worker threads. The minimal Alpine container environment lacks the GNU
# 'timeout' binary (timeout: not found).
# Target: Implement a pure Bash subshell watchdog wrapper 'run_with_timeout':
#   - Spawn command in background subshell
#   - Spawn a parallel timer watchdog
#   - If command finishes first, terminate timer and exit 0
#   - If timer expires first, kill command (escalating to kill -9) and exit 124
# ==============================================================================
set -euo pipefail

TIMEOUT_SEC=1
MODE="${1:-normal}"

# BROKEN / BLOCKED:
# Naive synchronous call with no timeout protection:
if [[ "$MODE" == "hang" ]]; then
  python3 upstream_rpc.py --hang
else
  python3 upstream_rpc.py
fi

echo "CALL_SUCCESSFUL"
