#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.17 (The Exit Trap)
# ==============================================================================
# Robust zero-pollution scratch sandbox runner with deterministic signal traps.
# ==============================================================================

set -euo pipefail

SCRATCH_DIR=""
PID_FILE="./active_job.pid"

# ------------------------------------------------------------------------------
# Step 1: Cleanup Handler
# ------------------------------------------------------------------------------
cleanup() {
    local exit_status=$?

    echo "[CLEANUP] Invoking emergency cleanup (exit_status: $exit_status)..." >&2

    # Safely purge scratch directory
    if [[ -n "${SCRATCH_DIR:-}" && -d "$SCRATCH_DIR" ]]; then
        rm -rf "$SCRATCH_DIR"
    fi

    # Safely remove PID lockfile
    if [[ -n "${PID_FILE:-}" && -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi

    exit "$exit_status"
}

# Step 2: Register cleanup trap across EXIT, INT, and TERM
trap cleanup EXIT INT TERM

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
