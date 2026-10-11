#!/usr/bin/env bash
set -euo pipefail

rm -f processed.log feed.raw
python3 generate_feed.py
chmod +x ingest.sh generate_feed.py
