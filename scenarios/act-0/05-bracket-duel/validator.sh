#!/usr/bin/env bash
# ==============================================================================
# Pre-Flight Deployment Validator
# Target: Verify TARGET_ENV and DEPLOY_TIER without syntax crashes
# ==============================================================================
set -euo pipefail

TARGET_ENV="${1:-}"
DEPLOY_TIER="${2:-standard}"

# TODO: Modernize these legacy bracket tests into [[ ... ]]:
# Notice how single brackets crash if TARGET_ENV is empty or contains spaces!
if [ $TARGET_ENV = "production" -a $DEPLOY_TIER = "critical" ]; then
  echo "DEPLOY_VERDICT: MANUAL_APPROVAL_REQUIRED"
elif [ $TARGET_ENV = "staging" -o $TARGET_ENV = "dev" ]; then
  echo "DEPLOY_VERDICT: AUTO_APPROVED"
elif [ -z $TARGET_ENV ]; then
  echo "DEPLOY_VERDICT: TARGET_ENV_MISSING"
else
  echo "DEPLOY_VERDICT: UNKNOWN_TARGET"
fi
