#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

chmod +x "$WORKSPACE/gateway_caller.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/upstream_rpc.py" 2>/dev/null || true

echo "[SETUP COMPLETE] Configured gateway caller sandbox."
