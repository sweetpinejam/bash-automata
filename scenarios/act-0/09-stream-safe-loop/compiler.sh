#!/usr/bin/env bash
# ==============================================================================
# Configuration Compiler
# Objective: Read template.conf and write final.conf with exact fidelity
# ==============================================================================
set -euo pipefail

input="template.conf"
output="final.conf"
rm -f "$output"

# BROKEN: The for loop below word-splits on spaces, stripping indentation
# and corrupting backslashes:
for line in $(cat "$input"); do
  echo "$line" >> "$output"
done

echo "COMPILATION_COMPLETE"
