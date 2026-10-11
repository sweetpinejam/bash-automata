#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.18 (The Lockfile Mutex)
# ==============================================================================
# Atomic filesystem mutual exclusion with stale lock detection and exit traps.
# ==============================================================================

set -euo pipefail

LOCK_DIR="./sync.lock"

# ------------------------------------------------------------------------------
# Mutex Lock Acquisition
# ------------------------------------------------------------------------------
acquire_lock() {
    # Attempt 1: Atomic creation of directory
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "$$" > "$LOCK_DIR/pid"
        return 0
    fi

    # Lock directory exists: Inspect for stale lock
    if [[ -f "$LOCK_DIR/pid" ]]; then
        local owner_pid
        owner_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")"

        if [[ -n "$owner_pid" ]] && kill -0 "$owner_pid" 2>/dev/null; then
            echo "LOCK_ACQUIRE_FAILED: Active process (PID $owner_pid) holds lock." >&2
            exit 1
        fi
        echo "[WARN] Stale lock detected (dead PID: ${owner_pid:-unknown}). Reclaiming..." >&2
    else
        echo "[WARN] Corrupted lock directory without PID file. Reclaiming..." >&2
    fi

    # Purge stale lock and attempt atomic acquisition again
    rm -rf "$LOCK_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "$$" > "$LOCK_DIR/pid"
        echo "Stale lock reclaimed successfully (PID: $$)."
        return 0
    fi

    echo "LOCK_ACQUIRE_FAILED: Race condition during stale lock reclaim." >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Mutex Lock Release
# ------------------------------------------------------------------------------
release_lock() {
    local exit_status=$?
    if [[ -d "$LOCK_DIR" ]]; then
        # Only unlink if current process owns the lock
        if [[ -f "$LOCK_DIR/pid" ]] && [[ "$(cat "$LOCK_DIR/pid" 2>/dev/null)" == "$$" ]]; then
            rm -rf "$LOCK_DIR"
        fi
    fi
    exit "$exit_status"
}

trap release_lock EXIT INT TERM

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------
acquire_lock

HOLD_FOR_TEST="false"
for arg in "$@"; do
    if [[ "$arg" == "--hold" ]]; then
        HOLD_FOR_TEST="true"
    fi
done

if [[ "$HOLD_FOR_TEST" == "true" ]]; then
    echo "[-] Holding lock for concurrency test (sleeping 3s)..."
    sleep 3
fi

# Process incoming events
EVENTS_FILE="./events.jsonl"
total_events=0
total_amount=0

if [[ -f "$EVENTS_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// /}" ]] && continue
        total_events=$(( total_events + 1 ))
        if [[ "$line" =~ \"amount\":[[:space:]]*([0-9]+) ]]; then
            total_amount=$(( total_amount + BASH_REMATCH[1] ))
        fi
    done < "$EVENTS_FILE"
fi

cat <<EOF > "./sync_summary.json"
{
  "pid": $$,
  "status": "SUCCESS",
  "events_processed": $total_events,
  "total_amount": $total_amount,
  "completed_at": $(date +%s)
}
EOF

echo "MUTEX_WORKER: pid=$$, events_processed=$total_events, status=SUCCESS"
