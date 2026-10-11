# Code Blueprint: Parameter Expansion Defaults & Guards

Use Bash parameter expansion syntax to specify fallback values or throw mandatory errors:

```bash
# Blueprint Pattern:
# Default fallback if unset or empty:
PORT="${PORT:-8080}"
DB_HOST="${DB_HOST:-localhost}"

# Mandatory requirement (throws error and exits if unset/empty):
API_SECRET="${API_SECRET:?API_SECRET is required}"
```

> **Key Rule**: Use `:-` for safe defaults, and `:?` to abort with a fatal diagnostic when mandatory parameters are missing.
