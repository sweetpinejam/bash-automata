#!/usr/bin/env bash
# ==============================================================================
# Automated Financial Ledger Auditor
# Problem: total_amount is ALWAYS 0 due to subshell scoping!
# Goal: Fix the loop to retain variable state in the current shell
# ==============================================================================
set -euo pipefail

total_amount=0

# BROKEN: The pipe '| while' spawns a subshell process for the loop.
# Any changes to total_amount vanish when the subshell terminates!
tail -n +2 ledger.csv | while IFS=, read -r tx_id account amount; do
  [[ -n "$amount" ]] || continue
  (( total_amount += amount ))
done

echo "FINAL_AUDIT_TOTAL=$total_amount" > audit.out
echo "FINAL_AUDIT_TOTAL=$total_amount"
