#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.18: THE LOCKFILE MUTEX (Atomic Filesystem Locking)
# ==============================================================================
# Synchronized event worker with atomic mutex locking and stale lock detection.
#
# MISSION:
# 1. Enable defensive execution ('set -euo pipefail').
# 2. Implement 'acquire_lock()':
#    - Use atomic 'mkdir "$LOCK_DIR"' (NEVER 'mkdir -p' or '[ -d ]').
#    - On success: write PID ($$) to "$LOCK_DIR/pid".
#    - On failure: check if "$LOCK_DIR/pid" exists and if the owner process
#      is still alive via 'kill -0 "$owner_pid"'.
#      * If alive: print "LOCK_ACQUIRE_FAILED" and exit 1.
#      * If dead: log warning, remove stale lock, and retry atomic acquisition.
# 3. Implement 'release_lock()' registered on 'EXIT INT TERM':
#    - Remove "$LOCK_DIR" only if current PID ($$) owns it.
# 4. Process records in './events.jsonl', calculate total count and sum of amounts,
#    and write './sync_summary.json'.
# 5. Support '--hold' (sleep 3s for collision testing).
# ==============================================================================

set -euo pipefail

LOCK_DIR="./sync.lock"

# ------------------------------------------------------------------------------
# Mutex Lock Acquisition
# ------------------------------------------------------------------------------
acquire_lock() {
    # BROKEN STARTER CODE:
    # Checking directory existence then creating it is vulnerable to TOCTOU race conditions!
    # And 'mkdir -p' never fails when directory exists!
    if [[ -d "$LOCK_DIR" ]]; then
        echo "LOCK_ACQUIRE_FAILED: Lock directory already exists." >&2
        exit 1
    fi
    mkdir -p "$LOCK_DIR"

    # TODO: Implement atomic mutex acquisition using 'mkdir "$LOCK_DIR"':
    # 1. Try atomic mkdir:
    #    if mkdir "$LOCK_DIR" 2>/dev/null; then
    #        echo "$$" > "$LOCK_DIR/pid"
    #        return 0
    #    fi
    # 2. If mkdir fails, inspect "$LOCK_DIR/pid":
    #    - If owner PID is alive (kill -0 "$owner_pid" 2>/dev/null):
    #        echo "LOCK_ACQUIRE_FAILED" >&2
    #        exit 1
    #    - If owner PID is dead (stale lock):
    #        rm -rf "$LOCK_DIR"
    #        retry atomic mkdir
}

# ------------------------------------------------------------------------------
# Mutex Lock Release
# ------------------------------------------------------------------------------
release_lock() {
    local exit_status=$?
    # TODO: Safely unlink $LOCK_DIR if owned by current PID ($$)
    if [[ -d "$LOCK_DIR" ]]; then
        rm -rf "$LOCK_DIR"
    fi
    exit "$exit_status"
}

# TODO: Register lock release trap on EXIT, INT, and TERM
# trap release_lock ...

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
