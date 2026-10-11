#!/usr/bin/env bash
# [BROKEN STARTER] Synchronous blocking pipe
# Vulnerability: Stalls upstream producer when downstream consumer throttles.
set -euo pipefail

# TODO: Refactor using a non-blocking named pipe (mkfifo) and background consumer.
# Register an EXIT trap to ensure the FIFO is cleanly unlinked.

cat | python3 process.py
