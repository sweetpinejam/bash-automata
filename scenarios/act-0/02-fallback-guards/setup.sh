#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/.env" "$WORKSPACE/.env.runtime"
if [[ -f "$WORKSPACE/env_injector.sh" ]]; then
    chmod +x "$WORKSPACE/env_injector.sh"
fi

echo "[SETUP COMPLETE] Environment reset for Drill 0.02"
