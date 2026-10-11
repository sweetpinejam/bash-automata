#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.10 (The Subshell Ghost)
# ==============================================================================
set -euo pipefail

INPUT_LEDGER="${1:-ledger.csv}"
OUTPUT_REPORT="${2:-audit_report.tsv}"

[[ -f "$INPUT_LEDGER" ]] || { echo "Error: Ledger '$INPUT_LEDGER' not found" >&2; exit 1; }

TOTAL_TX=0
TOTAL_CREDITS=0
TOTAL_DEBITS=0
FLAGGED_FRAUD=0
declare -A BALANCES=()

rm -f "fraud_alerts.log"

while IFS=, read -r tx_id account_id type amount auth_code; do
    [[ -n "$amount" ]] || continue
    (( ++TOTAL_TX ))

    current_bal="${BALANCES[$account_id]:-0}"

    if [[ "$type" == "CREDIT" ]]; then
        (( TOTAL_CREDITS += amount ))
        (( current_bal += amount ))
    elif [[ "$type" == "DEBIT" ]]; then
        (( TOTAL_DEBITS += amount ))
        (( current_bal -= amount ))
    fi

    BALANCES["$account_id"]="$current_bal"

    # Fraud check
    if (( amount > 5000 )) && [[ "$auth_code" == "NONE" ]]; then
        (( ++FLAGGED_FRAUD ))
        echo "[FRAUD_ALERT] tx=$tx_id account=$account_id amount=$amount reason=UNAUTHORIZED_LARGE_TRANSFER" >> "fraud_alerts.log"
    fi
done < <(tail -n +2 "$INPUT_LEDGER")

NET_BALANCE=$(( TOTAL_CREDITS - TOTAL_DEBITS ))
ACCOUNTS_TRACKED="${#BALANCES[@]}"

cat <<EOF > "$OUTPUT_REPORT"
METRIC	VALUE
TOTAL_TX	$TOTAL_TX
TOTAL_CREDITS	$TOTAL_CREDITS
TOTAL_DEBITS	$TOTAL_DEBITS
NET_BALANCE	$NET_BALANCE
FLAGGED_FRAUD	$FLAGGED_FRAUD
ACCOUNTS_TRACKED	$ACCOUNTS_TRACKED
EOF

echo "AUDIT_COMPLETE: txs=$TOTAL_TX, credits=$TOTAL_CREDITS, debits=$TOTAL_DEBITS, net=$NET_BALANCE, fraud=$FLAGGED_FRAUD, accounts=$ACCOUNTS_TRACKED"
