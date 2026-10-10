#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

# Ensure starter script is executable
if [[ -f "$WORKSPACE/cleaner.sh" ]]; then
    chmod +x "$WORKSPACE/cleaner.sh"
fi

# Clean prior run state
rm -rf "$WORKSPACE/archived runs"
mkdir -p "$WORKSPACE/deploy artifacts"

# Seed test artifacts containing spaces in file names
echo "telemetry=ok timestamp=1700000000" > "$WORKSPACE/deploy artifacts/run telemetry.log"
echo "error=none code=0" > "$WORKSPACE/deploy artifacts/crash dump.txt"

echo "[SETUP COMPLETE] Staged test artifacts in: $WORKSPACE/deploy artifacts"
