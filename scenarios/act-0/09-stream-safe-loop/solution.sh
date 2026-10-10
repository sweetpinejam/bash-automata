#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Configuration Compiler
# ==============================================================================
set -euo pipefail

input="template.conf"
output="final.conf"
rm -f "$output"

# Canonical stream-safe while loop:
# 1. IFS= prevents stripping leading/trailing whitespace
# 2. -r prevents backslash escaping
# 3. || [[ -n "$line" ]] guarantees un-terminated last line is read
while IFS= read -r line || [[ -n "$line" ]]; do
  echo "$line" >> "$output"
done < "$input"

echo "COMPILATION_COMPLETE"
