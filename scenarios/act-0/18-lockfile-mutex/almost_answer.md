# Tactical Blueprint: Atomic Mutex with Stale Lock Recovery

To achieve mutual exclusion without race conditions and without permanent deadlocks from killed processes:

---

## 1. Atomic Acquisition via `mkdir`
Never use `[ -d dir ]` or `mkdir -p`. Use bare `mkdir`:

```bash
LOCK_DIR="./sync.lock"

acquire_lock() {
    # 1. Attempt atomic directory creation
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "$$" > "$LOCK_DIR/pid"
        return 0
    fi

    # 2. Collision detected: audit lock owner
    if [[ -f "$LOCK_DIR/pid" ]]; then
        local owner_pid
        owner_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")"

        # Check if the process is genuinely running
        if [[ -n "$owner_pid" ]] && kill -0 "$owner_pid" 2>/dev/null; then
            echo "LOCK_ACQUIRE_FAILED: Active process (PID $owner_pid) holds lock." >&2
            exit 1
        fi
        echo "[WARN] Stale lock detected (dead PID $owner_pid). Reclaiming..." >&2
    fi

    # 3. Purge stale lock and acquire
    rm -rf "$LOCK_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "$$" > "$LOCK_DIR/pid"
        return 0
    fi

    echo "LOCK_ACQUIRE_FAILED" >&2
    exit 1
}
```

---

## 2. Lock Release via Trap
Ensure the lock is unlinked upon normal completion or crash, verifying PID ownership:

```bash
release_lock() {
    local exit_status=$?
    if [[ -d "$LOCK_DIR" ]]; then
        if [[ -f "$LOCK_DIR/pid" ]] && [[ "$(cat "$LOCK_DIR/pid" 2>/dev/null)" == "$$" ]]; then
            rm -rf "$LOCK_DIR"
        fi
    fi
    exit "$exit_status"
}

trap release_lock EXIT INT TERM
```
