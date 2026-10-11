#!/usr/bin/env bash
# ==============================================================================
# Service Control Dispatcher
# Goal: Cleanly route commands using case ... in ... esac
# ==============================================================================
set -euo pipefail

action="${1:-help}"
pid_file="service.pid"

# TODO: Refactor into a case "$action" in ... esac dispatcher:
# - "start": record current PID ($$) into $pid_file, output "SERVICE_STARTED"
# - "stop": remove $pid_file, output "SERVICE_STOPPED"
# - "status": check if $pid_file exists, output "STATUS_RUNNING" or "STATUS_STOPPED"
# - "-h" | "--help" | "help": output usage and exit 0
# - "*": output error message to stderr and exit 1

if [ "$action" = "start" ]; then
  echo "$$" > "$pid_file"
  echo "SERVICE_STARTED"
elif [ "$action" = "stop" ]; then
  rm -f "$pid_file"
  echo "SERVICE_STOPPED"
fi
