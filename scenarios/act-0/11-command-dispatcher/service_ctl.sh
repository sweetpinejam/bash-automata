#!/usr/bin/env bash
# ==============================================================================
# Service Control Dispatcher
# Goal: Cleanly route commands using case ... in ... esac
# ==============================================================================
set -euo pipefail

action="${1:-help}"
pid_file="service.pid"

# TODO: Refactor into a case "$action" in ... esac dispatcher:
# - "start": echo "$$" > "$pid_file"; echo "SERVICE_STARTED"
# - "stop": rm -f "$pid_file"; echo "SERVICE_STOPPED"
# - "status": if [[ -f "$pid_file" ]]; then echo "STATUS_RUNNING"; else echo "STATUS_STOPPED"; fi
# - "-h" | "--help" | "help": echo "USAGE: service_ctl.sh {start|stop|status|-h|--help}"; exit 0
# - "*": echo "ERROR: Unknown action '$action'" >&2; exit 1

if [ "$action" = "start" ]; then
  echo "$$" > "$pid_file"
  echo "SERVICE_STARTED"
elif [ "$action" = "stop" ]; then
  rm -f "$pid_file"
  echo "SERVICE_STOPPED"
fi
