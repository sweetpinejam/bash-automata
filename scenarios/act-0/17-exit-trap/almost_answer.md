# Code Blueprint: Automated Cleanup with `trap`

Guarantee resource cleanup on script completion, error, or termination signals:

```bash
# Blueprint Pattern:
cleanup() {
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT INT TERM
```

> **Key Rule**: Trapping `EXIT` ensures the cleanup action executes on normal exit, error exit (under `set -e`), or fatal signals (`INT`, `TERM`).
