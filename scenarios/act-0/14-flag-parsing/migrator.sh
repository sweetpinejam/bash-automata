#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.14: Flag & Argument Parsing (Enterprise CLI Normalizer)
# ==============================================================================
# INSTRUCTIONS:
# Implement an enterprise CLI argument parser in pure Bash.
#
# HARD CONSTRAINT:
# All flag handling MUST use the canonical while-case-shift loop:
#   while [[ $# -gt 0 ]]; do ... done
#
# Supported Options (in ANY order):
#   -e <val> | --env=<val> | --env <val>    (development, staging, production; default: development)
#   -d | --dry-run                           (boolean, default: false)
#   -v | --verbose                           (boolean, default: false)
#   -t <val> | --timeout=<val> | --timeout <val> (integer 5..3600, default: 30)
#   --batch-size=<val> | --batch-size <val>  (integer 1..10000, default: 100)
#   --force                                  (boolean, default: false)
#   --                                       (end-of-options marker)
#   Positional argument: migration target    (default: "all")
#
# Requirements:
# 1. Reject unknown options starting with '-' with exit 1.
# 2. Validate env is one of: development, staging, production (else exit 1).
# 3. Validate timeout is numeric and between 5 and 3600 (else exit 1).
# 4. Generate "migration_plan.json" with format:
#    {
#      "env": "<ENV>",
#      "dry_run": <true|false>,
#      "verbose": <true|false>,
#      "timeout": <N>,
#      "batch_size": <N>,
#      "force": <true|false>,
#      "target": "<TARGET>"
#    }
# 5. Print summary:
#    "MIGRATOR_READY: env=<E>, dry_run=<D>, timeout=<T>, batch=<B>, target=<M>"
# ==============================================================================
set -euo pipefail

ENV="development"
DRY_RUN="false"
VERBOSE="false"
TIMEOUT=30
BATCH_SIZE=100
FORCE="false"
TARGET="all"

# --- STEP 1: ARGUMENT PARSING LOOP (while [[ $# -gt 0 ]]) ---
# TODO: Implement the while loop with case matching and shift:
# Remember to handle:
# - Boolean flags: set variable, shift 1
# - Attached values (--flag=val): extract via ${1#*=}, shift 1
# - Space-separated values (--flag val): validate $2, extract, shift 2
# - End-of-options marker (--): shift 1, record remaining arguments, break
# - Positional targets (*): assign TARGET="$1", shift 1
# - Unknown options (-*): echo error to stderr, exit 1


# --- STEP 2: PARAMETER VALIDATIONS ---
# TODO: Validate that $ENV is one of: development, staging, production
# If not, echo error to stderr and exit 1.


# TODO: Validate that $TIMEOUT is numeric and between 5 and 3600


# --- STEP 3: WRITE MIGRATION PLAN JSON ---
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

# --- STEP 4: OUTPUT SUMMARY ---
echo "MIGRATOR_READY: env=$ENV, dry_run=$DRY_RUN, timeout=$TIMEOUT, batch=$BATCH_SIZE, target=$TARGET"
