#!/usr/bin/env bash
# ==============================================================================
# Database Migration CLI Runner
# Objective: Robustly parse options (-e/--env, -d/--dry-run, -v/--verbose)
# ==============================================================================
set -euo pipefail

env="development"
dry_run="false"
verbose="false"

# BROKEN: Hardcoded argument positions fail when flags are reordered
if [[ "${1:-}" == "--env" ]]; then
  env="${2:-development}"
fi

# TODO: Refactor using a while (( $# > 0 )) loop with case and shift:
# - "-e" | "--env") env="$2"; shift 2 ;;
# - "-d" | "--dry-run") dry_run="true"; shift ;;
# - "-v" | "--verbose") verbose="true"; shift ;;
# - *) echo "Unknown arg: $1" >&2; shift ;;

cat <<EOF > migration.cfg
ENV=$env
DRY_RUN=$dry_run
VERBOSE=$verbose
EOF

echo "MIGRATION_CONFIGURED"
