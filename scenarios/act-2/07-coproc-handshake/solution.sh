#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Two-Way Coprocess Security Handshake
# ==============================================================================
set -euo pipefail

SECRET="SECRET_KEY_99"

# Launch two-way interactive coprocess
coproc AUTH { python3 security_cli.py; }

# Step 1: Read challenge
read -r challenge <&"${AUTH[0]}"

# Step 2: Send secret response
echo "RESPONSE: $SECRET" >&"${AUTH[1]}"

# Step 3: Read session ID
read -r session_line <&"${AUTH[0]}"

# Step 4: Send ACK
echo "ACK" >&"${AUTH[1]}"

# Step 5: Read auth verdict
read -r verdict <&"${AUTH[0]}"
echo "$verdict"

# Extract and save session token
session_id="${session_line##*: }"
echo "$session_id" > session.out

# Wait for coprocess to exit cleanly
wait "$AUTH_PID"
