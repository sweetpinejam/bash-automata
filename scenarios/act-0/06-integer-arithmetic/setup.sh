#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/metrics_rollup.tsv"

if [[ -f "$WORKSPACE/aggregator.sh" ]]; then
    chmod +x "$WORKSPACE/aggregator.sh"
fi

cat << 'EOF' > "$WORKSPACE/samples.log"
timestamp=1700000001 method=GET status=200 latency_ms=45 size_bytes=512
timestamp=1700000002 method=POST status=201 latency_ms=120 size_bytes=1024
timestamp=1700000003 method=GET status=200 latency_ms=80 size_bytes=256
timestamp=1700000004 method=GET status=304 latency_ms=15 size_bytes=64
timestamp=1700000005 method=GET status=200 latency_ms=190 size_bytes=2048
timestamp=1700000006 method=PUT status=400 latency_ms=90 size_bytes=128
timestamp=1700000007 method=GET status=404 latency_ms=30 size_bytes=128
timestamp=1700000008 method=POST status=500 latency_ms=450 size_bytes=512
timestamp=1700000009 method=GET status=200 latency_ms=60 size_bytes=512
timestamp=1700000010 method=GET status=200 latency_ms=110 size_bytes=1024
EOF

echo "[SETUP COMPLETE] Seeded 10 traffic samples in samples.log"
