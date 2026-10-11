#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

if [[ -f "$WORKSPACE/cleaner.sh" ]]; then
    chmod +x "$WORKSPACE/cleaner.sh"
fi

# Clean prior state
rm -rf "$WORKSPACE/archived runs"
rm -rf "$WORKSPACE/deploy artifacts"

# Seed test artifacts containing spaces in directory and file names
mkdir -p "$WORKSPACE/deploy artifacts/release 1.0"
echo "telemetry=ok timestamp=1700000000" > "$WORKSPACE/deploy artifacts/run telemetry.log"
echo "error=none code=0" > "$WORKSPACE/deploy artifacts/crash dump.txt"
echo "release_build=prod status=success" > "$WORKSPACE/deploy artifacts/release 1.0/build report.log"

echo "[SETUP COMPLETE] Staged test artifacts in: $WORKSPACE/deploy artifacts"
