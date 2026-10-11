#!/usr/bin/env python3
"""Aggregates partition summaries into final metric ledger."""
import glob
import json
import sys
from pathlib import Path

files = sorted(glob.glob("summary_part_*.tsv"))
if not files:
    print("ERROR: No summary files found!", file=sys.stderr)
    sys.exit(1)

total_success = 0
total_errors = 0
partitions_processed = []

for fpath in files:
    content = Path(fpath).read_text(encoding="utf-8").strip()
    if not content:
        continue
    parts = content.split("\t")
    if len(parts) >= 3:
        partitions_processed.append(parts[0])
        total_success += int(parts[1])
        total_errors += int(parts[2])

result = {
    "partitions": partitions_processed,
    "total_success": total_success,
    "total_errors": total_errors,
    "total_events": total_success + total_errors,
}

Path("final_metrics.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print(f"REDUCED: {len(partitions_processed)} partitions, {total_success + total_errors} total events.")
