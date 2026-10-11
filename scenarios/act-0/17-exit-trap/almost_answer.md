# Tactical Blueprint: Deterministic Cleanup Trap (`trap ... EXIT INT TERM`)

To ensure transient files and PID locks are cleaned up unconditionally upon normal exit or abnormal termination:

---

## 1. Register Traps Before Allocating Resources
Always initialize variables to empty strings and register your trap handler **before** creating directories or files:

```bash
SCRATCH_DIR=""
PID_FILE="./active_job.pid"

cleanup() {
    local exit_status=$?

    # Defensive check: ensure SCRATCH_DIR is non-empty before running rm -rf
    if [[ -n "${SCRATCH_DIR:-}" && -d "$SCRATCH_DIR" ]]; then
        rm -rf "$SCRATCH_DIR"
    fi

    if [[ -n "${PID_FILE:-}" && -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi

    exit "$exit_status"
}

trap cleanup EXIT INT TERM
```

---

## 2. Key Mechanics
- **`local exit_status=$?`**: The very first instruction in `cleanup()` captures the original exit code. If you run other commands first, `$?` will be reset to `0`.
- **`EXIT`**: Pseudocall fired when bash terminates normally or on error (`set -e`).
- **`INT`**: Fired when interrupted by `Ctrl+C`.
- **`TERM`**: Fired when killed by orchestrators or `kill <pid>`.
- **`mktemp -d "./.sandbox_XXXXXX"`**: Allocates a uniquely named directory atomically.
