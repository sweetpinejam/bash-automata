#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

# Clean state
rm -f "$WORKSPACE"/api.log "$WORKSPACE"/api_state.json "$WORKSPACE"/api.lock

# Generate queue
cat <<'EOF' > "$WORKSPACE/queue.txt"
job_01
job_02
job_03
job_04
job_05
job_06
job_07
job_08
job_09
job_10
job_11
job_12
job_13
job_14
job_15
job_16
EOF

chmod +x "$WORKSPACE/dispatcher.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/mock_api.py" 2>/dev/null || true

echo "[SETUP COMPLETE] Initialized 16-job queue and API environment."
