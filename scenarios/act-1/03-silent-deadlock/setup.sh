#!/usr/bin/env bash
set -euo pipefail

rm -f req.fifo resp.fifo handshake.log
mkfifo req.fifo
mkfifo resp.fifo
chmod +x agent.sh
