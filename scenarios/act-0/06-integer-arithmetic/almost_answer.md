# Code Blueprint: Pure Bash Integer Arithmetic

Replace external utilities like `expr` with Bash native arithmetic evaluation (`(( ... ))`) and expansion (`$(( ... ))`):

```bash
# Blueprint Pattern:
# In-place mutations (no subshell, no $ needed inside (( ))):
(( total_count += 1 ))
(( total_latency += latency ))
if (( status >= 500 )); then
  (( error_count += 1 ))
fi

# Value expansion / assignment:
avg_latency=$(( total_latency / total_count ))
err_pct=$(( (error_count * 100) / total_count ))
```

> **Key Rule**: Use `(( ... ))` for statements/mutations, and `$(( ... ))` when you need the evaluated result assigned to a variable or expanded into a command.
