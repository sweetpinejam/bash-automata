#!/usr/bin/env python3
"""Supervisory controller daemon for Scenario 1.03: The Silent Deadlock."""
import os
import sys
import time


def log(msg: str):
    sys.stderr.write(f"[{time.strftime('%X')}] [CONTROLLER] {msg}\n")


def main():
    req_fifo = "req.fifo"
    resp_fifo = "resp.fifo"

    log(f"Supervisor initialized (PID: {os.getpid()}). Awaiting agent connection on {req_fifo}...")

    # Step 1: Wait for incoming request on req.fifo
    # In POSIX, opening in 'r' mode blocks until the agent opens req.fifo for writing
    try:
        with open(req_fifo, "r", encoding="utf-8") as rf:
            msg = rf.readline().strip()
    except Exception as exc:
        log(f"Failed to read from request FIFO: {exc}")
        sys.exit(1)

    log(f"Received inbound payload: '{msg}'")
    if msg != "PING":
        log(f"Invalid handshake token: '{msg}' (expected 'PING')")
        sys.exit(1)

    # Step 2: Acknowledge handshake on resp.fifo
    log(f"Transmitting acknowledgement to agent via {resp_fifo}...")
    try:
        with open(resp_fifo, "w", encoding="utf-8") as wf:
            wf.write("HANDSHAKE_ACK_RECEIVED\n")
            wf.flush()
    except Exception as exc:
        log(f"Failed to write to response FIFO: {exc}")
        sys.exit(1)

    log("Handshake acknowledgement dispatched. Controller exiting cleanly.")
    sys.exit(0)


if __name__ == "__main__":
    main()
