#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Automated Financial Ledger Auditor
# ==============================================================================
set -euo pipefail

total_amount=0

# Use process substitution < <(...) so the while loop runs in the
# CURRENT shell process, preserving total_amount!
while IFS=, read -r tx_id account amount; do
  [[ -n "$amount" ]] || continue
  (( total_amount += amount ))
done < <(tail -n +2 ledger.csv)

echo "FINAL_AUDIT_TOTAL=$total_amount" > audit.out
echo "FINAL_AUDIT_TOTAL=$total_amount"
