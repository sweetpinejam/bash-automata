#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE"/transactions.commit "$WORKSPACE"/drain.log "$WORKSPACE"/worker.pid

cat <<'EOF' > "$WORKSPACE/jobs.queue"
tx_01
tx_02
tx_03
tx_04
tx_05
tx_06
tx_07
tx_08
tx_09
tx_10
EOF

chmod +x "$WORKSPACE/worker_service.sh" 2>/dev/null || true

echo "[SETUP COMPLETE] Initialized 10-job transaction queue."
