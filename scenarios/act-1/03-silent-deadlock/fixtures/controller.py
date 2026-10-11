#!/usr/bin/env python3
"""Supervisory Controller for Mission 1.03."""
import os
import sys

def main():
    req_fifo = "req.fifo"
    resp_fifo = "resp.fifo"

    # Step 1: Controller opens req.fifo to read incoming ping
    with open(req_fifo, "r", encoding="utf-8") as rf:
        msg = rf.readline().strip()

    if msg != "PING":
        print(f"Unexpected message: {msg}", file=sys.stderr)
        sys.exit(1)

    # Step 2: Controller sends ACK on resp.fifo
    with open(resp_fifo, "w", encoding="utf-8") as wf:
        wf.write("HANDSHAKE_ACK_RECEIVED\n")

    sys.exit(0)

if __name__ == "__main__":
    main()
