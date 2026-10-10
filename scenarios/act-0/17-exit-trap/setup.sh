#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"
if [[ -f "$WORKSPACE/job.sh" ]]; then
    chmod +x "$WORKSPACE/job.sh"
fi

rm -f "$WORKSPACE/job.lock"

echo "[SETUP COMPLETE] Workspace primed for Exit Trap drill."
