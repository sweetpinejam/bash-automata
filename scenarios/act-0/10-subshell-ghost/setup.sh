#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/audit_report.tsv" "$WORKSPACE/fraud_alerts.log"

if [[ -f "$WORKSPACE/auditor.sh" ]]; then
    chmod +x "$WORKSPACE/auditor.sh"
fi

cat << 'EOF' > "$WORKSPACE/ledger.csv"
tx_id,account_id,type,amount,auth_code
TX101,ACC_01,CREDIT,2500,AUTH_OK
TX102,ACC_02,CREDIT,8000,AUTH_OK
TX103,ACC_01,DEBIT,500,AUTH_OK
TX104,ACC_03,CREDIT,1500,AUTH_OK
TX105,ACC_02,DEBIT,6000,NONE
TX106,ACC_03,DEBIT,300,AUTH_OK
TX107,ACC_01,CREDIT,1200,AUTH_OK
EOF

echo "[SETUP COMPLETE] Seeded 7 ledger transactions in ledger.csv"
