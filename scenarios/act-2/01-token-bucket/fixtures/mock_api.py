#!/usr/bin/env python3
"""Mock Upstream API with strict concurrency monitoring."""
import fcntl
import json
import os
import sys
import time
from pathlib import Path

MAX_CONCURRENCY = 4
STATE_FILE = Path("api_state.json")
LOG_FILE = Path("api.log")
LOCK_FILE = Path("api.lock")


def main():
    if len(sys.argv) < 2:
        print("Usage: mock_api.py <item_id>", file=sys.stderr)
        sys.exit(2)

    item_id = sys.argv[1]

    with open(LOCK_FILE, "a+") as lock_f:
        fcntl.flock(lock_f, fcntl.LOCK_EX)
        state = {"active": 0, "max_observed": 0, "breaches": 0, "processed": []}
        if STATE_FILE.exists():
            try:
                state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            except Exception:
                pass

        state["active"] += 1
        if state["active"] > state["max_observed"]:
            state["max_observed"] = state["active"]

        if state["active"] > MAX_CONCURRENCY:
            state["breaches"] += 1
            with open(LOG_FILE, "a") as log:
                log.write(f"BREACH_429: item={item_id} active={state['active']} max_allowed={MAX_CONCURRENCY}\n")
            STATE_FILE.write_text(json.dumps(state), encoding="utf-8")
            fcntl.flock(lock_f, fcntl.LOCK_UN)
            print(f"HTTP 429 Too Many Requests: item={item_id}", file=sys.stderr)
            sys.exit(1)

        STATE_FILE.write_text(json.dumps(state), encoding="utf-8")
        fcntl.flock(lock_f, fcntl.LOCK_UN)

    # Simulate brief network workload
    time.sleep(0.04)

    with open(LOCK_FILE, "a+") as lock_f:
        fcntl.flock(lock_f, fcntl.LOCK_EX)
        if STATE_FILE.exists():
            try:
                state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            except Exception:
                state = {"active": 1, "processed": []}
        state["active"] = max(0, state.get("active", 1) - 1)
        state.setdefault("processed", []).append(item_id)
        with open(LOG_FILE, "a") as log:
            log.write(f"OK: item={item_id} remaining_active={state['active']}\n")
        STATE_FILE.write_text(json.dumps(state), encoding="utf-8")
        fcntl.flock(lock_f, fcntl.LOCK_UN)

    print(f"OK {item_id}")
    sys.exit(0)


if __name__ == "__main__":
    main()
