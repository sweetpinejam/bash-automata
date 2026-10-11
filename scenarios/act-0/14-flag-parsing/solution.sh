#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.14 (Flag & Argument Parsing)
# ==============================================================================
set -euo pipefail

ENV="development"
DRY_RUN="false"
VERBOSE="false"
TIMEOUT=30
BATCH_SIZE=100
FORCE="false"
TARGET="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --env=*)
            ENV="${1#*=}"
            shift
            ;;
        -e|--env)
            [[ $# -ge 2 ]] || { echo "Error: Missing argument for $1" >&2; exit 1; }
            ENV="$2"
            shift 2
            ;;
        --timeout=*)
            TIMEOUT="${1#*=}"
            shift
            ;;
        -t|--timeout)
            [[ $# -ge 2 ]] || { echo "Error: Missing argument for $1" >&2; exit 1; }
            TIMEOUT="$2"
            shift 2
            ;;
        --batch-size=*)
            BATCH_SIZE="${1#*=}"
            shift
            ;;
        --batch-size)
            [[ $# -ge 2 ]] || { echo "Error: Missing argument for $1" >&2; exit 1; }
            BATCH_SIZE="$2"
            shift 2
            ;;
        --)
            shift
            if [[ $# -gt 0 ]]; then
                TARGET="$1"
                shift $#
            fi
            break
            ;;
        -*)
            echo "Error: Unknown option '$1'" >&2
            exit 1
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# Validations
case "$ENV" in
    development|staging|production)
        ;;
    *)
        echo "Error: Invalid environment '$ENV'. Must be development, staging, or production." >&2
        exit 1
        ;;
esac

if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || (( TIMEOUT < 5 || TIMEOUT > 3600 )); then
    echo "Error: Timeout must be an integer between 5 and 3600" >&2
    exit 1
fi

if ! [[ "$BATCH_SIZE" =~ ^[0-9]+$ ]] || (( BATCH_SIZE < 1 || BATCH_SIZE > 10000 )); then
    echo "Error: Batch size must be an integer between 1 and 10000" >&2
    exit 1
fi

cat <<EOF > "migration_plan.json"
{
  "env": "$ENV",
  "dry_run": $DRY_RUN,
  "verbose": $VERBOSE,
  "timeout": $TIMEOUT,
  "batch_size": $BATCH_SIZE,
  "force": $FORCE,
  "target": "$TARGET"
}
EOF

echo "MIGRATOR_READY: env=$ENV, dry_run=$DRY_RUN, timeout=$TIMEOUT, batch=$BATCH_SIZE, target=$TARGET"
