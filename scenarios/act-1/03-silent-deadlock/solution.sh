#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Agent IPC Handshake
# ==============================================================================
set -euo pipefail

[[ -p req.fifo ]] || mkfifo req.fifo
[[ -p resp.fifo ]] || mkfifo resp.fifo

trap 'rm -f req.fifo resp.fifo' EXIT

python3 controller.py &
controller_pid=$!

# Send PING in background or write first to satisfy controller's read on req.fifo:
echo "PING" > req.fifo &

# Read the response cleanly
cat resp.fifo > handshake.log

wait "$controller_pid"
echo "HANDSHAKE_COMPLETE"
