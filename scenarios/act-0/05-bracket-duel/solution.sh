#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Pre-Flight Deployment Validator
# ==============================================================================
set -euo pipefail

TARGET_ENV="${1:-}"
DEPLOY_TIER="${2:-standard}"

# Modern Bash compound test [[ ... ]]
# 1. Immune to word-splitting on empty or space-filled variables
# 2. Uses native && and || instead of archaic -a and -o
if [[ "$TARGET_ENV" == "production" && "$DEPLOY_TIER" == "critical" ]]; then
  echo "DEPLOY_VERDICT: MANUAL_APPROVAL_REQUIRED"
elif [[ "$TARGET_ENV" == "staging" || "$TARGET_ENV" == "dev" ]]; then
  echo "DEPLOY_VERDICT: AUTO_APPROVED"
elif [[ -z "$TARGET_ENV" ]]; then
  echo "DEPLOY_VERDICT: TARGET_ENV_MISSING"
else
  echo "DEPLOY_VERDICT: UNKNOWN_TARGET"
fi
