#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 2.07: THE TWO-WAY COPROCESS DIALOGUE (Security Vault Authenticator)
# ==============================================================================
# Production authentication client negotiating with an interactive security CLI.
#
# CRISIS:
# INCIDENT-6421: Automated deployment keys cannot be retrieved. The security service
# enforces an interactive, multi-step challenge-response handshake:
#   Step 1. Read CHALLENGE from security_cli
#   Step 2. Send RESPONSE: SECRET_KEY_99
#   Step 3. Read SESSION_ID from security_cli
#   Step 4. Send ACK
#   Step 5. Receive AUTH_SUCCESS and extract session token
#
# The legacy script uses a standard one-way pipe, which cannot support two-way
# conversation and immediately aborts without authenticating!
#
# MISSION:
# Refactor 'auth_bot.sh' to establish a bidirectional coprocess ('coproc') dialogue
# with 'security_cli.py' using linked file descriptors, saving the session UUID
# into 'session.out'.
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
# BROKEN STATE: One-Way Pipe Antipattern
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# Standard Unix pipes ('|') are strictly unidirectional. They cannot conduct
# an interactive multi-turn dialogue where the script must read prompts and
# send replies sequentially to the same running process.
#
# TODO:
# 1. Spawn a coprocess: coproc AUTH { python3 "$SECURITY_CLI"; }
# 2. Read from coprocess: read -r line <&"${AUTH[0]}"
# 3. Write to coprocess: echo "..." >&"${AUTH[1]}"
# 4. Save session token to $OUTPUT_FILE and wait for $AUTH_PID

log_info "Attempting authentication via pipeline (BROKEN)..."

echo "RESPONSE: $SECRET" | python3 "$SECURITY_CLI" || true

log_error "Authentication failed: one-way pipe cannot complete multi-turn handshake."

cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "FAILED"
}
EOF

echo "SESSION_FAILED"
exit 1
