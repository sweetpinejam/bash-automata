#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/clean_payloads.log" "$WORKSPACE/error_diagnostics.log" "$WORKSPACE/stream_triage_report.json"

if [[ -f "$WORKSPACE/triage.sh" ]]; then
    chmod +x "$WORKSPACE/triage.sh"
fi

echo "[SETUP COMPLETE] Initialized workspace for Drill 0.12"
