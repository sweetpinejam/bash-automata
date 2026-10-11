# Code Blueprint: Local Function Variable Scoping

By default, all variables in Bash functions are global. Protect calling scopes by declaring variables with `local`:

```bash
# Blueprint Pattern:
process_backup_day() {
  local day_id="$1"
  local chunk

  for day_id in {10..12}; do
    echo "  Processing chunk $day_id" >/dev/null
  done
}
```

> **Key Rule**: Declare every variable inside a function with `local`. If a loop variable has the same name as a variable in the caller, without `local` it overwrites the outer loop variable!
