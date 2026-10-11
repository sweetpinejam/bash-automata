# Code Blueprint & Almost-Answer: The Subshell Ghost

If you need structural loop templates for `auditor.sh`:

### 1. Process Substitution Loop (Preserving Shell Memory)
```bash
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

    # Fraud detection
    if (( amount > 5000 )) && [[ "$auth_code" == "NONE" ]]; then
        (( ++FLAGGED_FRAUD ))
        echo "[FRAUD_ALERT] tx=$tx_id account=$account_id amount=$amount reason=UNAUTHORIZED_LARGE_TRANSFER" >> "fraud_alerts.log"
    fi
done < <(tail -n +2 "$INPUT_LEDGER")
```
