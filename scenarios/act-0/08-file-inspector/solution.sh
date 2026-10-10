#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Automated Pre-Flight Deployment Checker
# ==============================================================================
set -euo pipefail

config_file="config/app.conf"
release_dir="releases"
app_bin="bin/app"

# Check 1: config_file exists and is non-empty (-s)
if [[ ! -s "$config_file" ]]; then
  echo "FAIL: config/app.conf missing or empty"
  exit 1
fi

# Check 2: release_dir is a directory (-d)
if [[ ! -d "$release_dir" ]]; then
  echo "FAIL: releases directory missing"
  exit 1
fi

# Check 3: app_bin is executable (-x)
if [[ ! -x "$app_bin" ]]; then
  echo "FAIL: bin/app not executable"
  exit 1
fi

echo "ALL_CHECKS_PASSED"
exit 0
