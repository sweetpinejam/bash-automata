#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: In-Memory Event Log Sanitizer
# ==============================================================================
set -euo pipefail

output_file="events.sanitized"
rm -f "$output_file"

while IFS= read -r line; do
  # In-memory global pattern replacement:
  # //pattern/replacement replaces all matches in the string
  sanitized="${line//dev.internal/prod.external}"
  sanitized="${sanitized//SECRET_/REDACTED_}"

  echo "$sanitized" >> "$output_file"
done < events.raw

echo "SANITIZATION_COMPLETE"
