#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"
cd "$WORKSPACE"

rm -rf sync.lock sync_summary.json

cat <<'EOF' > events.jsonl
{"event_id": "evt-101", "type": "ORDER_PLACED", "amount": 150}
{"event_id": "evt-102", "type": "PAYMENT_CAPTURED", "amount": 150}
{"event_id": "evt-103", "type": "ORDER_PLACED", "amount": 75}
{"event_id": "evt-104", "type": "SHIPPED", "amount": 0}
{"event_id": "evt-105", "type": "REFUND", "amount": 25}
EOF

if [[ -f "$WORKSPACE/worker.sh" ]]; then
    chmod +x "$WORKSPACE/worker.sh"
fi

echo "[SETUP COMPLETE] Workspace primed for Lockfile Mutex drill."
