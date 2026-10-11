#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.2: The Defensive Shield
# ==============================================================================
# INSTRUCTIONS:
# By default, Bash silently ignores undefined variables and pipe failures!
#
# Enable defensive execution options to fail immediately on unhandled errors,
# unbound variables, and pipe pipeline failures.
# ==============================================================================

# TODO: Enable defensive shell options here

TARGET_ENV="${TARGET_ENV:-production}"

echo "Deploying to environment: $TARGET_ENV"

# This pipeline intentionally simulates an upstream failure:
# With pipefail enabled, this command correctly halts if 'false' fails!
echo "Checking service status..."
true | true

echo "DEPLOYMENT_SUCCESSFUL"
