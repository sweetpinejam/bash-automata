#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/migration_plan.json" "$WORKSPACE/migration.cfg"

if [[ -f "$WORKSPACE/migrator.sh" ]]; then
    chmod +x "$WORKSPACE/migrator.sh"
fi

echo "[SETUP COMPLETE] Environment initialized for Drill 0.14"
