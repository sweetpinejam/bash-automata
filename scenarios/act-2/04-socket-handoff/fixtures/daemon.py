#!/usr/bin/env python3
"""Unix Domain Socket IPC Daemon."""
import os
import signal
import socket
import sys
from pathlib import Path

SOCKET_PATH = Path("daemon.sock")
PID_FILE = Path("daemon.pid")

running = True


def handle_term(signum, frame):
    global running
    running = False


signal.signal(signal.SIGTERM, handle_term)
signal.signal(signal.SIGINT, handle_term)


def main():
    global running

    if SOCKET_PATH.exists():
        # Standard POSIX socket behavior: bind fails if socket file exists!
        raise OSError(f"Address already in use: {SOCKET_PATH}")

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(SOCKET_PATH))
    server.listen(16)
    server.settimeout(0.2)

    PID_FILE.write_text(str(os.getpid()), encoding="utf-8")

    try:
        while running:
            try:
                conn, _ = server.accept()
                data = conn.recv(64)
                if b"PING" in data:
                    conn.sendall(b"PONG\n")
                conn.close()
            except socket.timeout:
                continue
            except Exception:
                break
    finally:
        server.close()
        if SOCKET_PATH.exists():
            SOCKET_PATH.unlink()
        if PID_FILE.exists():
            PID_FILE.unlink()


if __name__ == "__main__":
    main()
