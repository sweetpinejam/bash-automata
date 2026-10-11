#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.10: The Subshell Ghost (Financial Ledger Auditor & Fraud Detector)
# ==============================================================================
# INSTRUCTIONS:
# Implement a multi-account financial ledger reconciliation bot in pure Bash.
#
# HARD CONSTRAINT:
# Strictly NO pipeline into while loop ('| while')!
# The loop MUST execute in the parent shell context using process substitution:
#   while ...; do
#     ...
#   done < <(tail -n +2 "$INPUT_LEDGER")
#
# CSV format:
#   tx_id,account_id,type,amount,auth_code
#
# Requirements:
# 1. Positional arguments:
#    $1 = input ledger (default: "ledger.csv")
#    $2 = output report (default: "audit_report.tsv")
# 2. Accumulate in main shell memory:
#    - TOTAL_TX: total transactions processed
#    - TOTAL_CREDITS: sum of CREDIT amounts
#    - TOTAL_DEBITS: sum of DEBIT amounts
#    - NET_BALANCE = TOTAL_CREDITS - TOTAL_DEBITS
#    - BALANCES["$account_id"]: running balance per account
# 3. Fraud Detection:
#    - If amount > 5000 and auth_code == "NONE":
#      - Increment FLAGGED_FRAUD
#      - Append alert to "fraud_alerts.log":
#        "[FRAUD_ALERT] tx=<id> account=<acc> amount=<amt> reason=UNAUTHORIZED_LARGE_TRANSFER"
# 4. Generate "audit_report.tsv" with metrics:
#    TOTAL_TX, TOTAL_CREDITS, TOTAL_DEBITS, NET_BALANCE, FLAGGED_FRAUD, ACCOUNTS_TRACKED
# 5. Print summary:
#    "AUDIT_COMPLETE: txs=<N>, credits=<C>, debits=<D>, net=<B>, fraud=<F>, accounts=<A>"
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

# --- STEP 1: PARSE TRANSACTIONS IN PARENT SHELL VIA PROCESS SUBSTITUTION ---
# TODO: Implement loop using '< <(tail -n +2 "$INPUT_LEDGER")'.
# Inside loop:
#   1. Increment TOTAL_TX
#   2. If type == "CREDIT":
#        Add amount to TOTAL_CREDITS
#        Add amount to BALANCES["$account_id"]
#      If type == "DEBIT":
#        Add amount to TOTAL_DEBITS
#        Subtract amount from BALANCES["$account_id"]
#   3. If amount > 5000 and auth_code == "NONE":
#        Increment FLAGGED_FRAUD
#        Append alert to "fraud_alerts.log"


# --- STEP 2: COMPUTE DERIVED METRICS ---
NET_BALANCE=$(( TOTAL_CREDITS - TOTAL_DEBITS ))
ACCOUNTS_TRACKED="${#BALANCES[@]}"

# --- STEP 3: WRITE AUDIT REPORT TSV ---
cat <<EOF > "$OUTPUT_REPORT"
METRIC	VALUE
TOTAL_TX	$TOTAL_TX
TOTAL_CREDITS	$TOTAL_CREDITS
TOTAL_DEBITS	$TOTAL_DEBITS
NET_BALANCE	$NET_BALANCE
FLAGGED_FRAUD	$FLAGGED_FRAUD
ACCOUNTS_TRACKED	$ACCOUNTS_TRACKED
EOF

# --- STEP 4: OUTPUT SUMMARY METRICS ---
echo "AUDIT_COMPLETE: txs=$TOTAL_TX, credits=$TOTAL_CREDITS, debits=$TOTAL_DEBITS, net=$NET_BALANCE, fraud=$FLAGGED_FRAUD, accounts=$ACCOUNTS_TRACKED"
