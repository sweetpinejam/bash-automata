#!/usr/bin/env bash
set -euo pipefail

rm -f summary.txt
cat <<'EOF' > samples.log
status=200 latency=45
status=200 latency=55
status=500 latency=120
status=200 latency=40
status=503 latency=140
EOF

chmod +x aggregator.sh
