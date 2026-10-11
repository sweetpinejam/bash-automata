#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

# Clean prior run
rm -f "$WORKSPACE"/daemon.pid "$WORKSPACE"/daemon.sock

chmod +x "$WORKSPACE/service_ctl.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/daemon.py" 2>/dev/null || true
chmod +x "$WORKSPACE/client.py" 2>/dev/null || true

# Start initial instance with detached stdio to avoid holding parent pipes open
(
  cd "$WORKSPACE"
  python3 daemon.py >/dev/null 2>&1 &
  sleep 0.1
)

echo "[SETUP COMPLETE] Daemon initialized and listening on daemon.sock."
