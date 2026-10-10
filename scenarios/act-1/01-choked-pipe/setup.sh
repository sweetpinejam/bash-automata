#!/usr/bin/env bash
# ==============================================================================
# Setup for Act I, Scenario 1.1: The Choked Pipe
# Initializes workspace state and validates executable permissions.
# ==============================================================================
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

# Ensure scripts in workspace are executable
if [[ -f "$WORKSPACE/ingest.sh" ]]; then
    chmod +x "$WORKSPACE/ingest.sh"
fi

if [[ -f "$WORKSPACE/process.py" ]]; then
    chmod +x "$WORKSPACE/process.py"
fi

echo "[CRISIS INJECTED] Synchronous blocking ingest pipeline staged in $WORKSPACE"
exit 0
