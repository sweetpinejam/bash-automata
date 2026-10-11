#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"
cd "$WORKSPACE"

rm -f deploy_crash.dump deploy_status.json

if [[ -f "$WORKSPACE/deploy.sh" ]]; then
    chmod +x "$WORKSPACE/deploy.sh"
fi

echo "[SETUP COMPLETE] Workspace primed for Defensive Shield drill."
