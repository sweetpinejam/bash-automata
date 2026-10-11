#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Upstream Gateway Caller with Pure Bash Timeout
# ==============================================================================
set -euo pipefail

TIMEOUT_SEC=1
MODE="${1:-normal}"

run_with_timeout() {
  local timeout_sec="$1"
  shift

  "$@" &
  local cmd_pid=$!

  (
    sleep "$timeout_sec"
    kill -TERM "$cmd_pid" 2>/dev/null || true
    sleep 0.1
    kill -9 "$cmd_pid" 2>/dev/null || true
  ) &
  local timer_pid=$!

  if wait "$cmd_pid" 2>/dev/null; then
    kill "$timer_pid" 2>/dev/null || true
    wait "$timer_pid" 2>/dev/null || true
    return 0
  else
    kill "$timer_pid" 2>/dev/null || true
    wait "$timer_pid" 2>/dev/null || true
    return 124
  fi
}

cmd=("python3" "upstream_rpc.py")
if [[ "$MODE" == "hang" ]]; then
  cmd+=("--hang")
fi

if run_with_timeout "$TIMEOUT_SEC" "${cmd[@]}"; then
  echo "CALL_SUCCESSFUL"
  exit 0
else
  echo "TIMEOUT_INTERRUPTED: Upstream call exceeded ${TIMEOUT_SEC}s threshold" >&2
  exit 124
fi
