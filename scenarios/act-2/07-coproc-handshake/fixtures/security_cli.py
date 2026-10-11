#!/usr/bin/env python3
"""Interactive Challenge-Response Security CLI."""
import sys
import time

EXPECTED_TOKEN = "SECRET_KEY_99"


def main():
    # Step 1: Issue challenge
    print("CHALLENGE: 0xDEADBEEF", flush=True)

    # Step 2: Read client response
    line = sys.stdin.readline()
    if not line:
        print("ERROR: Connection severed before response", file=sys.stderr)
        sys.exit(1)

    response = line.strip()
    if response != f"RESPONSE: {EXPECTED_TOKEN}":
        print(f"ERROR: Invalid token '{response}'", file=sys.stderr)
        sys.exit(2)

    # Step 3: Issue session ID
    session_id = "sess_vault_998877"
    print(f"SESSION_ID: {session_id}", flush=True)

    # Step 4: Wait for client acknowledgment
    ack_line = sys.stdin.readline()
    if not ack_line or ack_line.strip() != "ACK":
        print("ERROR: Missing ACK", file=sys.stderr)
        sys.exit(3)

    # Step 5: Authenticated!
    print("AUTH_SUCCESS", flush=True)
    sys.exit(0)


if __name__ == "__main__":
    main()
