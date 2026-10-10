#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Service Control Dispatcher
# ==============================================================================
set -euo pipefail

action="${1:-help}"
pid_file="service.pid"

case "$action" in
  start)
    echo "$$" > "$pid_file"
    echo "SERVICE_STARTED"
    ;;
  stop)
    rm -f "$pid_file"
    echo "SERVICE_STOPPED"
    ;;
  status)
    if [[ -f "$pid_file" ]]; then
      echo "STATUS_RUNNING"
    else
      echo "STATUS_STOPPED"
    fi
    ;;
  -h|--help|help)
    echo "USAGE: service_ctl.sh {start|stop|status|-h|--help}"
    ;;
  *)
    echo "ERROR: Unknown action '$action'" >&2
    exit 1
    ;;
esac
