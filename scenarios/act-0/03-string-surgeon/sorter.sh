#!/usr/bin/env bash
# ==============================================================================
# Automated In-Memory Artifact Sorter
# Goal: Sort incoming/* files into categorized/<ext>/<filename>
# Constraint: Use pure Bash string manipulation (no basename, cut, sed, awk)
# ==============================================================================
set -euo pipefail

mkdir -p categorized

for filepath in incoming/*; do
  # Ensure the glob matched an actual file
  [[ -f "$filepath" ]] || continue

  # TODO: Extract filename and extension in-memory:
  # 1. Strip leading path to get filename (e.g., "incoming/foo.js" -> "foo.js")
  # 2. Extract trailing extension (e.g., "foo.js" -> "js", "bar.tar.gz" -> "gz")
  filename="$filepath"   # FIXME: Replace with ${filepath##*/}
  ext="unknown"          # FIXME: Replace with ${filename##*.}

  mkdir -p "categorized/$ext"
  mv "$filepath" "categorized/$ext/$filename"
done

echo "SORT_COMPLETE"
