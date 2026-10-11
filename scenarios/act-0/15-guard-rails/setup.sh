#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -rf "$WORKSPACE/dist"

if [[ -f "$WORKSPACE/publisher.sh" ]]; then
    chmod +x "$WORKSPACE/publisher.sh"
fi

echo "[SETUP COMPLETE] Environment reset for Drill 0.15"
