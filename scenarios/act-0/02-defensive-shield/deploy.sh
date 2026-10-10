#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.2: The Defensive Shield
# ==============================================================================
# INSTRUCTIONS:
# By default, Bash silently ignores undefined variables and pipe failures!
#
# 1. Add 'set -euo pipefail' directly below this header.
# 2. Fix the unbound variable TARGET_ENV so it has a default value or is set.
# ==============================================================================

# TODO: Add defensive flags here

TARGET_ENV="${TARGET_ENV:-production}"

echo "Deploying to environment: $TARGET_ENV"

# This pipeline intentionally simulates an upstream failure:
# With pipefail enabled, this command correctly halts if 'false' fails!
echo "Checking service status..."
true | true

echo "DEPLOYMENT_SUCCESSFUL"
