#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/backup_manifest.tsv"

if [[ -f "$WORKSPACE/backup_bot.sh" ]]; then
    chmod +x "$WORKSPACE/backup_bot.sh"
fi

echo "[SETUP COMPLETE] Initialized workspace for Drill 0.13"
