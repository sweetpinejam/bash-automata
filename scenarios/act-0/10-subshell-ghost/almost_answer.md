# Code Blueprint: Subshell Avoidance with Process Substitution

Piping a command into a `while` loop (`cmd | while ...`) spawns the loop in a subshell, causing all variable mutations to vanish when the loop finishes. Use process substitution instead:

```bash
# Blueprint Pattern:
while IFS=, read -r tx_id account amount; do
  [[ -n "$amount" ]] || continue
  (( total_amount += amount ))
done < <(tail -n +2 ledger.csv)
```

> **Key Rule**: `< <(command)` runs `command` in a file descriptor pipe while keeping the `while` loop in the main shell environment, preserving variable state.
