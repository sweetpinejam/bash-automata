#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

if [[ -f "$WORKSPACE/validator.sh" ]]; then
    chmod +x "$WORKSPACE/validator.sh"
fi

echo "[SETUP COMPLETE] Initialized workspace for Drill 0.05"
