#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 2.07 (The Two-Way Coprocess Dialogue)
# ==============================================================================
# Bidirectional challenge-response handshake using Bash coprocess (coproc).
# ==============================================================================

set -euo pipefail

SECRET="SECRET_KEY_99"
SECURITY_CLI="security_cli.py"
OUTPUT_FILE="session.out"
STATUS_FILE="auth_status.json"

log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] $*" >&2
}

log_warn() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] $*" >&2
}

log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [ERROR] $*" >&2
}

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --secret)
            SECRET="$2"
            shift 2
            ;;
        --cli)
            SECURITY_CLI="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

rm -f "$OUTPUT_FILE" "$STATUS_FILE"

log_info "Initializing security vault authenticator (PID: $$)..."
log_info "Security CLI target: $SECURITY_CLI"
log_info "Output destination:  $OUTPUT_FILE"

# ------------------------------------------------------------------------------
# Launch Bidirectional Coprocess
# ------------------------------------------------------------------------------
log_info "Spawning interactive coprocess for security dialogue..."
coproc AUTH { python3 "$SECURITY_CLI"; }

# Step 1: Read challenge from coprocess (stdout)
read -r challenge <&"${AUTH[0]}"
log_info "Received challenge: $challenge"

# Step 2: Send secret response to coprocess (stdin)
log_info "Submitting authentication response..."
echo "RESPONSE: $SECRET" >&"${AUTH[1]}"

# Step 3: Read issued session identifier
read -r session_line <&"${AUTH[0]}"
log_info "Received session payload: $session_line"

# Step 4: Send client acknowledgment
log_info "Sending protocol acknowledgment (ACK)..."
echo "ACK" >&"${AUTH[1]}"

# Step 5: Read final authentication verdict
read -r verdict <&"${AUTH[0]}"
log_info "Handshake verdict: $verdict"
echo "$verdict"

# Extract and persist session UUID token
session_id="${session_line##*: }"
echo "$session_id" > "$OUTPUT_FILE"
log_info "Persisted session token '$session_id' to $OUTPUT_FILE."

# Wait for coprocess process termination
wait "$AUTH_PID"

cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "AUTHENTICATED",
  "session_token": "$session_id"
}
EOF

log_info "Coprocess dialogue completed cleanly."
