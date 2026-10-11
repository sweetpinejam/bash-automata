#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.17: THE EXIT TRAP (Deterministic Resource Cleanup)
# ==============================================================================
# MISSION:
# 1. Enable defensive execution ('set -euo pipefail').
# 2. Implement 'cleanup()' that:
#    - Preserves incoming exit status ($?)
#    - Safely removes the scratch directory ($SCRATCH_DIR) if it exists
#    - Safely removes the PID file ($PID_FILE) if it exists
#    - Exits with the preserved exit status
# 3. Register the trap on EXIT, INT, and TERM *before* creating resources.
# 4. Provision a temporary scratch directory using mktemp:
#    SCRATCH_DIR="$(mktemp -d "./.sandbox_XXXXXX")"
# 5. Record the script's PID ($$) into PID_FILE="./active_job.pid".
# 6. Process the sandbox payload and emit './job_manifest.json' on success.
# ==============================================================================

set -euo pipefail

SCRATCH_DIR=""
PID_FILE="./active_job.pid"

# ------------------------------------------------------------------------------
# Step 1: Cleanup Handler
# ------------------------------------------------------------------------------
cleanup() {
    # TODO: Capture exit status immediately before other commands overwrite $?
    # local exit_status=$?

    echo "[CLEANUP] Invoking emergency cleanup..." >&2

    # TODO: Safely remove $SCRATCH_DIR if set and exists
    # TODO: Safely remove $PID_FILE if set and exists

    # TODO: Exit with preserved exit status
    # exit "$exit_status"
}

# TODO: Step 2 - Register cleanup trap on EXIT, INT, and TERM
# trap cleanup ...

# ------------------------------------------------------------------------------
# Step 3: Provision Isolated Scratch Sandbox
# ------------------------------------------------------------------------------
SCRATCH_DIR="$(mktemp -d "./.sandbox_XXXXXX")"
echo "$$" > "$PID_FILE"
echo "[-] Provisioned isolated scratch directory: $SCRATCH_DIR (PID: $$)"

# ------------------------------------------------------------------------------
# Step 4: Sandbox Processing & Flag Handling
# ------------------------------------------------------------------------------
SIMULATE_CRASH="false"
HOLD_FOR_SIGNAL="false"

for arg in "$@"; do
    case "$arg" in
        --simulate-crash)
            SIMULATE_CRASH="true"
            ;;
        --hold)
            HOLD_FOR_SIGNAL="true"
            ;;
    esac
done

# Generate synthetic transient artifacts inside sandbox
cat <<EOF > "$SCRATCH_DIR/config.env"
RUN_ID=$$
SANDBOX_PATH=$SCRATCH_DIR
STATUS=ACTIVE
EOF

cat <<EOF > "$SCRATCH_DIR/payload.dat"
TRANSIENT_RAW_PAYLOAD_CHUNK_$$
EOF

if [[ "$HOLD_FOR_SIGNAL" == "true" ]]; then
    echo "[-] Holding execution for signal test (sleeping 5s)..."
    sleep 5
fi

if [[ "$SIMULATE_CRASH" == "true" ]]; then
    echo "[!] Simulating unexpected process failure..." >&2
    # This unhandled failure should trigger the exit trap immediately!
    /bin/false
fi

# ------------------------------------------------------------------------------
# Step 5: Publish Results & Complete
# ------------------------------------------------------------------------------
cat <<EOF > "./job_manifest.json"
{
  "pid": $$,
  "status": "SUCCESS",
  "transient_sandbox": "$SCRATCH_DIR",
  "completed_at": $(date +%s)
}
EOF

echo "JOB_EXECUTED: pid=$$, scratch=$SCRATCH_DIR, status=SUCCESS"
