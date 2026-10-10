#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"
if [[ -f "$WORKSPACE/triage.sh" ]]; then
    chmod +x "$WORKSPACE/triage.sh"
fi

# Clean any existing logs
rm -f "$WORKSPACE/clean.log" "$WORKSPACE/error.log"

echo "[SETUP COMPLETE] Workspace primed for Stream Contract drill."
