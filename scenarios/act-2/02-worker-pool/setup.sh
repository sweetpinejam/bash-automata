#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE"/processed.log

# Generate 9 tasks with one slow task per batch
cat <<'EOF' > "$WORKSPACE/incoming.queue"
task_slow_01
task_fast_02
task_fast_03
task_slow_04
task_fast_05
task_fast_06
task_slow_07
task_fast_08
task_fast_09
EOF

chmod +x "$WORKSPACE/pool_manager.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/worker.py" 2>/dev/null || true

echo "[SETUP COMPLETE] Initialized 9 incoming tasks."
