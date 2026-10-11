#!/usr/bin/env bash
# ==============================================================================
# Agent IPC Handshake
# Problem: Deadlocks because it tries to read the response before sending the request!
# ==============================================================================
set -euo pipefail

# Ensure FIFOs exist
[[ -p req.fifo ]] || mkfifo req.fifo
[[ -p resp.fifo ]] || mkfifo resp.fifo

# Launch background controller
python3 controller.py &
controller_pid=$!

# DEADLOCK BUG:
# Agent attempts to read from resp.fifo BEFORE controller receives anything on req.fifo!
# Both processes block waiting for a peer writer, freezing execution forever.
cat resp.fifo > handshake.log

# This line is never reached:
echo "PING" > req.fifo

wait "$controller_pid"
echo "HANDSHAKE_COMPLETE"
