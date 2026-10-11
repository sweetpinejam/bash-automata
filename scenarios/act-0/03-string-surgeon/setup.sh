#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -rf "$WORKSPACE/incoming" "$WORKSPACE/catalog_out"
mkdir -p "$WORKSPACE/incoming"

if [[ -f "$WORKSPACE/sorter.sh" ]]; then
    chmod +x "$WORKSPACE/sorter.sh"
fi

# Seed diverse artifacts to test compound extensions, no-extension binaries, etc.
echo "archive content" > "$WORKSPACE/incoming/backend-api.prod.tar.gz"
echo "archive content" > "$WORKSPACE/incoming/worker.service.tar.xz"
echo "config: prod" > "$WORKSPACE/incoming/config.cluster.yaml"
echo "dump table" > "$WORKSPACE/incoming/database-dump.backup.sql"
echo "#!/bin/sh" > "$WORKSPACE/incoming/daemon-runner"
echo "CREATE TABLE;" > "$WORKSPACE/incoming/schema.sql"
echo "#!/usr/bin/env bash" > "$WORKSPACE/incoming/deploy.sh"

echo "[SETUP COMPLETE] Seeded 7 test artifacts in incoming/"
