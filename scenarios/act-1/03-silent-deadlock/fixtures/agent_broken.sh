#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.03: THE SILENT DEADLOCK (Bidirectional Agent IPC Handshake)
# ==============================================================================
# Microservice IPC agent performing a bidirectional ping-pong sync handshake.
#
# CRISIS:
# The agent and supervisor communicate over two separate named pipes.
# Both processes attempt to open their receiving pipe for reading before writing,
# triggering Coffman Condition #4 (Circular Wait Deadlock) on open(2).
#
# MISSION:
# Decouple the handshake: dispatch the request into 'req.fifo' asynchronously
# (e.g. in the background or via non-blocking descriptor) so that the controller's
# read call unblocks while the agent listens on 'resp.fifo'.
# ==============================================================================

set -euo pipefail

REQ_FIFO="req.fifo"
RESP_FIFO="resp.fifo"
LOG_FILE="handshake.log"
MAIN_PID=$$

log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] $*" >&2
}

log_warn() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] $*" >&2
}

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --req-fifo)
            REQ_FIFO="$2"
            shift 2
            ;;
        --resp-fifo)
            RESP_FIFO="$2"
            shift 2
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        *)
            log_warn "Unknown flag: $1, continuing with defaults"
            shift
            ;;
    esac
done

# Ensure filesystem FIFOs exist
[[ -p "$REQ_FIFO" ]] || mkfifo "$REQ_FIFO"
[[ -p "$RESP_FIFO" ]] || mkfifo "$RESP_FIFO"

# Guarantee cleanup of transient FIFOs on exit (guarded against subshells)
trap 'if [[ "$BASHPID" == "$MAIN_PID" ]]; then rm -f "$REQ_FIFO" "$RESP_FIFO"; fi' EXIT INT TERM

log_info "Launching background supervisory controller..."
python3 controller.py &
controller_pid=$!

# ------------------------------------------------------------------------------
# BROKEN SYNCHRONOUS HANDSHAKE:
# ------------------------------------------------------------------------------
# 💥 THE DEADLOCK BUG:
# In POSIX, opening a FIFO for reading blocks until a writer connects!
# Agent waits here for controller to write to resp.fifo.
# But controller is currently waiting for agent to write to req.fifo!
# Both processes freeze in 'fifo_open' uninterruptible sleep state.
#
# TODO: Decouple the handshake:
# Option 1: Fire the request in the background:
#   echo "PING" > "$REQ_FIFO" &
#   cat "$RESP_FIFO" > "$LOG_FILE"
# Option 2: Use bidirectional read-write descriptor:
#   exec 3<> "$REQ_FIFO"
#   echo "PING" >&3
#   cat "$RESP_FIFO" > "$LOG_FILE"

cat "$RESP_FIFO" > "$LOG_FILE"

# This line is never reached under the broken architecture:
echo "PING" > "$REQ_FIFO"

wait "$controller_pid"
log_info "Handshake completed successfully."
echo "HANDSHAKE_COMPLETE"
