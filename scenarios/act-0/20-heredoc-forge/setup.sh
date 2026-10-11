#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"
cd "$WORKSPACE"

rm -f service.conf proxy.conf run.sh forge_manifest.json

if [[ -f "$WORKSPACE/forge.sh" ]]; then
    chmod +x "$WORKSPACE/forge.sh"
fi

echo "[SETUP COMPLETE] Workspace primed for Heredoc Forge drill."
