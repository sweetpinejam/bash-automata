#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -rf "$WORKSPACE/config" "$WORKSPACE/releases" "$WORKSPACE/bin" "$WORKSPACE/logs" "$WORKSPACE/current_release" "$WORKSPACE/health_report.json"

if [[ -f "$WORKSPACE/preflight.sh" ]]; then
    chmod +x "$WORKSPACE/preflight.sh"
fi

# Seed valid deployment infrastructure
mkdir -p "$WORKSPACE/config"
echo "port=8080 mode=production" > "$WORKSPACE/config/app.conf"

mkdir -p "$WORKSPACE/releases/v1.0"
mkdir -p "$WORKSPACE/bin"
echo '#!/bin/sh' > "$WORKSPACE/bin/app"
chmod +x "$WORKSPACE/bin/app"

ln -s "releases/v1.0" "$WORKSPACE/current_release"

mkdir -p "$WORKSPACE/logs"

echo "[SETUP COMPLETE] Initialized pre-flight infrastructure"
