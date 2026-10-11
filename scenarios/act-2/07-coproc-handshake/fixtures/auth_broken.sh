#!/usr/bin/env bash
# ==============================================================================
# Security Handshake Automation Bot
# Incident: The security CLI requires interactive two-way challenge-response:
#   1. Read CHALLENGE from security_cli
#   2. Write RESPONSE: SECRET_KEY_99
#   3. Read SESSION_ID from security_cli
#   4. Write ACK
#   5. Verify AUTH_SUCCESS and save session ID to session.out
# Target: Implement a two-way dialogue using Bash 'coproc' (coprocess file descriptors).
# ==============================================================================
set -euo pipefail

SECRET="SECRET_KEY_99"

# BROKEN / ONE-WAY PIPE:
# Naive pipeline cannot perform two-way conversational protocol:
echo "RESPONSE: $SECRET" | python3 security_cli.py

echo "SESSION_FAILED"
exit 1
