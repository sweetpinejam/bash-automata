#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE"/session.out

chmod +x "$WORKSPACE/auth_bot.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/security_cli.py" 2>/dev/null || true

echo "[SETUP COMPLETE] Configured security challenge sandbox."
