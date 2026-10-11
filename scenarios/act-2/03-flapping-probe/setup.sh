#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE"/probe_counter.txt

chmod +x "$WORKSPACE/canary_checker.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/health_endpoint.py" 2>/dev/null || true

echo "[SETUP COMPLETE] Configured canary probe sandbox."
