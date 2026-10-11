#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.08 (The Subreaper Tree)
# ==============================================================================
# Workload orchestrator with cascading process tree teardown.
# ==============================================================================

set -euo pipefail

PIPELINE_SCRIPT="pipeline.sh"
INIT_TIMEOUT=0.2
LOG_FILE="orchestrator.log"
STATUS_FILE="orchestration_status.json"

log_info() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] $*" >&2
}

log_warn() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] $*" >&2
}

log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [ERROR] $*" >&2
}

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --script)
            PIPELINE_SCRIPT="$2"
            shift 2
            ;;
        --timeout)
            INIT_TIMEOUT="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

rm -f pipeline.pid grandchildren.pids "$LOG_FILE" "$STATUS_FILE"

log_info "Booting workload orchestrator (PID: $$)..."
log_info "Target pipeline script: $PIPELINE_SCRIPT"

# ------------------------------------------------------------------------------
# Launch Pipeline Workload in Background
# ------------------------------------------------------------------------------
bash "$PIPELINE_SCRIPT" &
pipeline_pid=$!
log_info "Launched workload pipeline (PID: $pipeline_pid). Awaiting worker stabilization..."

sleep "$INIT_TIMEOUT"

if ! kill -0 "$pipeline_pid" 2>/dev/null; then
    log_error "Workload pipeline exited prematurely before teardown!"
    exit 1
fi

log_info "Workload pipeline active. Commencing cascading tree teardown..."

# ------------------------------------------------------------------------------
# Cascading Process Tree Teardown
# ------------------------------------------------------------------------------
# First terminate all children belonging to the pipeline's PPID:
pkill -P "$pipeline_pid" 2>/dev/null || true

# Then terminate the pipeline process itself:
kill -TERM "$pipeline_pid" 2>/dev/null || true

# Wait for pipeline process exit
wait "$pipeline_pid" 2>/dev/null || true

log_info "Workload pipeline and all descendant workers terminated cleanly."
echo "TEARDOWN_FINISHED"
