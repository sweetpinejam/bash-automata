#!/usr/bin/env python3
"""Test Client for Unix Domain Socket."""
import socket
import sys
from pathlib import Path

SOCKET_PATH = Path("daemon.sock")

if not SOCKET_PATH.exists():
    print("Socket file does not exist!", file=sys.stderr)
    sys.exit(1)

try:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(1.0)
    client.connect(str(SOCKET_PATH))
    client.sendall(b"PING\n")
    resp = client.recv(64)
    client.close()
    if b"PONG" in resp:
        print("PONG_OK")
        sys.exit(0)
    else:
        print(f"Unexpected response: {resp}", file=sys.stderr)
        sys.exit(2)
except Exception as e:
    print(f"Socket connection error: {e}", file=sys.stderr)
    sys.exit(1)
