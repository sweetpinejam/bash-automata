#!/usr/bin/env bash
# ==============================================================================
# Bash Automata - Interactive Game Launcher
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
exec "$SCRIPT_DIR/bin/automata" play "$@"
