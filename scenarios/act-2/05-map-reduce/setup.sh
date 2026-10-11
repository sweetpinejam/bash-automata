#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE"/summary_part_*.tsv "$WORKSPACE"/final_metrics.json

# Seed 4 partition files (100 events each)
for p in 1 2 3 4; do
  pfile="$WORKSPACE/part_$p.log"
  rm -f "$pfile"
  for (( i=1; i<=90; i++ )); do
    echo "evt=$i part=$p status=200 latency=12ms" >> "$pfile"
  done
  for (( i=91; i<=100; i++ )); do
    echo "evt=$i part=$p status=500 error=INTERNAL" >> "$pfile"
  done
done

chmod +x "$WORKSPACE/orchestrator.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/mapper.sh" 2>/dev/null || true
chmod +x "$WORKSPACE/reducer.py" 2>/dev/null || true

echo "[SETUP COMPLETE] Seeded 4 partition log files (400 total events)."
