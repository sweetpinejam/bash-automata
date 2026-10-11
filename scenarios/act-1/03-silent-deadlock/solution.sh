#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.03 (The Silent Deadlock)
# ==============================================================================
# Decoupled bidirectional IPC handshake resolving circular wait deadlock.
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
# Decoupled Handshake:
# ------------------------------------------------------------------------------
# Fire the request in the background so open(O_WRONLY) unblocks the controller's
# read call without stalling the agent shell:
echo "PING" > "$REQ_FIFO" &

# Read the controller's acknowledgement:
cat "$RESP_FIFO" > "$LOG_FILE"

wait "$controller_pid"
log_info "Handshake completed successfully with zero deadlocks."
echo "HANDSHAKE_COMPLETE"
