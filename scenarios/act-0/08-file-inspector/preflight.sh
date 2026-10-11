#!/usr/bin/env bash
# ==============================================================================
# Automated Pre-Flight Deployment Checker
# Objective: Validate prerequisites before starting service
# Required checks:
# 1. config/app.conf must exist and have non-zero size
# 2. releases/ must exist and be a directory
# 3. bin/app must exist and have executable permissions
# ==============================================================================
set -euo pipefail

config_file="config/app.conf"
release_dir="releases"
app_bin="bin/app"

# TODO: Implement the 3 defensive checks using file test operators:
# If any check fails, print an error and exit with code 1.

# Check 1: config_file exists and is non-empty
if false; then
  echo "FAIL: config/app.conf missing or empty"
  exit 1
fi

# Check 2: release_dir is a directory
if false; then
  echo "FAIL: releases directory missing"
  exit 1
fi

# Check 3: app_bin is executable
if false; then
  echo "FAIL: bin/app not executable"
  exit 1
fi

echo "ALL_CHECKS_PASSED"
exit 0
