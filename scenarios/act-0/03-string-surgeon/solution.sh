#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Automated In-Memory Artifact Sorter
# ==============================================================================
set -euo pipefail

mkdir -p categorized

for filepath in incoming/*; do
  [[ -f "$filepath" ]] || continue

  # In-memory string surgery:
  # ##*/ strips the longest prefix matching */ (yielding just the basename)
  filename="${filepath##*/}"
  # ##*. strips the longest prefix matching *. (yielding the trailing extension)
  ext="${filename##*.}"

  mkdir -p "categorized/$ext"
  mv "$filepath" "categorized/$ext/$filename"
done

echo "SORT_COMPLETE"
