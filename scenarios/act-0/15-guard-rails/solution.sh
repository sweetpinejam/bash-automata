#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Automated Release Publisher
# ==============================================================================
set -euo pipefail

run_tests() {
  ./mock_test.sh
}

build_bundle() {
  echo "v1.0.0-release" > dist/bundle.bin
}

sign_bundle() {
  echo "SIG_VALID" > dist/bundle.sig
}

# Clean, flattened short-circuit guard rails:
run_tests || { echo "ERROR: Tests failed" >&2; exit 1; }
build_bundle || { echo "ERROR: Build failed" >&2; exit 1; }
sign_bundle || { echo "ERROR: Signing failed" >&2; exit 1; }

echo "PUBLISH_SUCCESS"
