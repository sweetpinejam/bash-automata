# Code Blueprint: Atomic Directory Mutex & Trap Cleanup

In Linux POSIX filesystems, `mkdir` is an atomic kernel system call (`sys_mkdir`). Either it succeeds or it fails with `EEXIST`:

```bash
# Blueprint Pattern:
LOCK_DIR="sync.lock"

# Atomic acquisition:
mkdir "$LOCK_DIR" 2>/dev/null || { echo "LOCK_ACQUIRE_FAILED"; exit 1; }

# Automatic unlock on exit or termination:
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM
```

> **Key Rule**: Avoid `if [ -d "$DIR" ]` followed by `mkdir` (Time-of-Check to Time-of-Use race condition). Attempt `mkdir` directly and handle failure.
