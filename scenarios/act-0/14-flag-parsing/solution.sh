#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Database Migration CLI Runner
# ==============================================================================
set -euo pipefail

env="development"
dry_run="false"
verbose="false"

# Robust positional loop consuming flags with shift
while (( $# > 0 )); do
  case "$1" in
    -e|--env)
      env="${2:?Missing value for --env}"
      shift 2
      ;;
    -d|--dry-run)
      dry_run="true"
      shift
      ;;
    -v|--verbose)
      verbose="true"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      shift
      ;;
  esac
done

cat <<EOF > migration.cfg
ENV=$env
DRY_RUN=$dry_run
VERBOSE=$verbose
EOF

echo "MIGRATION_CONFIGURED"
