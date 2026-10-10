#!/usr/bin/env bash
# [BROKEN STARTER] Synchronous blocking pipe
# Vulnerability: Stalls upstream producer when downstream consumer throttles.
set -euo pipefail

# TODO: Refactor using named pipes (mkfifo) and background process supervision.
# Trap exit signals to ensure the FIFO is unlinked cleanly:
#   trap 'rm -f "$FIFO_PATH"' EXIT INT TERM

cat | python3 process.py
