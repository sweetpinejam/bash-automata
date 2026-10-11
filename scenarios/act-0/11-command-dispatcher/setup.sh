#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/service.pid"

if [[ -f "$WORKSPACE/service_ctl.sh" ]]; then
    chmod +x "$WORKSPACE/service_ctl.sh"
fi

echo "[SETUP COMPLETE] Environment initialized for Drill 0.11"
