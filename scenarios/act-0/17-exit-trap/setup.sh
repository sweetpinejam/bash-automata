#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"
cd "$WORKSPACE"

rm -f active_job.pid job_manifest.json job.lock
rm -rf .sandbox_*

if [[ -f "$WORKSPACE/job.sh" ]]; then
    chmod +x "$WORKSPACE/job.sh"
fi

echo "[SETUP COMPLETE] Workspace primed for Exit Trap drill."
