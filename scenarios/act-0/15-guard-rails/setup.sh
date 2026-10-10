#!/usr/bin/env bash
set -euo pipefail

rm -rf dist
mkdir -p dist

cat <<'EOF' > mock_test.sh
#!/bin/sh
exit 0
EOF
chmod +x mock_test.sh

chmod +x publisher.sh
