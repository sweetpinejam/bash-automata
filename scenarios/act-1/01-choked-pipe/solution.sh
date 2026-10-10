#!/usr/bin/env bash
# ==============================================================================
# Golden Reference Solution for Scenario 1.1: The Choked Pipe
# Implements POSIX named pipe decoupling with defensive signal traps.
# ==============================================================================
set -euo pipefail

FIFO="/tmp/telemetry_$$.fifo"
trap 'rm -f "$FIFO"' EXIT INT TERM

mkfifo "$FIFO"

# Spawn decoupled Python batch processor reading from the FIFO
python3 -c '
import sys

count = 0
buf = bytearray(65536)

with open("'"$FIFO"'", "rb") as f:
    while True:
        n = f.readinto(buf)
        if not n:
            break
        count += buf[:n].count(b"\n")

print(f"TOTAL_PROCESSED={count}")
' &
PY_PID=$!

# Stream stdin directly into the named pipe
cat > "$FIFO"

# Wait for consumer to flush and terminate cleanly
wait "$PY_PID"
