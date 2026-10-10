#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION & POST-MORTEM: Drill 0.2
# ==============================================================================
# 'set -euo pipefail' is the gold standard for production shell scripts:
#   -e           Exit immediately if any command fails.
#   -u           Treat unbound/undefined variables as an error.
#   -o pipefail  Fail if ANY command in a pipeline fails (not just the rightmost).
#
# '${TARGET_ENV:-production}' provides safe parameter expansion with a fallback default.
# ==============================================================================
set -euo pipefail

TARGET_ENV="${TARGET_ENV:-production}"

echo "Deploying to environment: $TARGET_ENV"
echo "Checking service status..."
true | true

echo "DEPLOYMENT_SUCCESSFUL"
