#!/usr/bin/env bash
set -euo pipefail

rm -f audit.out
cat <<'EOF' > ledger.csv
tx_id,account,amount
tx_101,acct_99,500
tx_102,acct_99,1250
tx_103,acct_12,2000
EOF

chmod +x auditor.sh
