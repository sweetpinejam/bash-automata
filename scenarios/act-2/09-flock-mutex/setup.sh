#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE"/metrics_dump.tsv "$WORKSPACE"/metrics.lock

chmod +x "$WORKSPACE/cron_writer.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/multi_runner.sh" 2>/dev/null || true

echo "[SETUP COMPLETE] Initialized metrics lock contention sandbox."
