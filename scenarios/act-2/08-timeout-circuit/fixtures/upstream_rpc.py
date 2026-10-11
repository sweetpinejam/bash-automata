#!/usr/bin/env python3
"""Simulated upstream RPC endpoint."""
import sys
import time

delay = 0.05
if len(sys.argv) > 1 and sys.argv[1] == "--hang":
    delay = 15.0

time.sleep(delay)
print("RPC_RESPONSE_OK")
sys.exit(0)
