#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.12 (The Stream Contract)
# ==============================================================================
set -euo pipefail

TEE_ERRORS=0
STDOUT_LOG="clean_payloads.log"
STDERR_LOG="error_diagnostics.log"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tee-errors)
            TEE_ERRORS=1
            shift
            ;;
        --stdout-log)
            STDOUT_LOG="${2:-}"
            [[ -n "$STDOUT_LOG" ]] || { echo "Error: Missing stdout log path" >&2; exit 1; }
            shift 2
            ;;
        --stderr-log)
            STDERR_LOG="${2:-}"
            [[ -n "$STDERR_LOG" ]] || { echo "Error: Missing stderr log path" >&2; exit 1; }
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

simulate_noisy_probe() {
    echo "DATA: host=edge-01 status=healthy metric=42"
    echo "ERROR: connection timeout on port 8080" >&2
    echo "DATA: host=edge-02 status=healthy metric=88"
    echo "ERROR: memory threshold exceeded 85%" >&2
    echo "DATA: host=edge-03 status=healthy metric=19"
    echo "ERROR: disk write latency spike 450ms" >&2
}

# Step 1: Execute probe with stream separation
if (( TEE_ERRORS == 1 )); then
    simulate_noisy_probe > "$STDOUT_LOG" 2> >(tee "$STDERR_LOG" >&2)
    # Wait for background tee to finish flushing
    sleep 0.1
else
    simulate_noisy_probe > "$STDOUT_LOG" 2> "$STDERR_LOG"
fi

# Step 2: Compute stream metrics
PAYLOAD_LINES=$(wc -l < "$STDOUT_LOG")
PAYLOAD_BYTES=$(wc -c < "$STDOUT_LOG")
ERROR_LINES=$(wc -l < "$STDERR_LOG")
ERROR_BYTES=$(wc -c < "$STDERR_LOG")

# Step 3: Emit JSON report
cat <<EOF > "stream_triage_report.json"
{
  "status": "TRIAGED",
  "payload_lines": $PAYLOAD_LINES,
  "payload_bytes": $PAYLOAD_BYTES,
  "error_lines": $ERROR_LINES,
  "error_bytes": $ERROR_BYTES,
  "cross_contamination": false
}
EOF

# Step 4: Output summary
echo "TRIAGE_COMPLETE: payload_lines=$PAYLOAD_LINES, error_lines=$ERROR_LINES, clean_log=$STDOUT_LOG, error_log=$STDERR_LOG"
