#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.08: THE SUBREAPER TREE (Job Orchestration Daemon)
# ==============================================================================
# Production job lifecycle supervisor that launches multi-process workloads.
#
# CRISIS:
# The orchestrator launches 'pipeline.sh' which spawns multiple background child
# workers. When terminating the pipeline via standard 'kill $pipeline_pid', the
# Linux kernel terminates only the direct pipeline leader. All grandchild workers
# are reparented to PID 1 (init / systemd) and survive indefinitely as orphaned
# background processes, hogging CPU and memory.
#
# MISSION:
# Refactor the orchestrator teardown sequence to eradicate the entire process
# tree (pipeline leader and all descendant background workers).
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

# Allow pipeline and its background workers to spawn and register PIDs
sleep "$INIT_TIMEOUT"

if ! kill -0 "$pipeline_pid" 2>/dev/null; then
    log_error "Workload pipeline exited prematurely before teardown!"
    exit 1
fi

log_info "Workload pipeline active. Commencing scheduled teardown..."

# ------------------------------------------------------------------------------
# BROKEN STATE: Naive Single-PID Signal Leaves Grandchildren Alive!
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# Standard 'kill' signals only the immediate target PID ($pipeline_pid).
# Because background children are not members of a dedicated isolated process group
# and no recursive PPID kill is issued, the grandchildren are reparented to PID 1
# and survive teardown!
#
# TODO: Terminate all child processes of the pipeline before or alongside
#       the pipeline process itself (e.g. using 'pkill -P "$pipeline_pid"' or
#       process group signaling).

kill -TERM "$pipeline_pid" 2>/dev/null || true

# Wait for pipeline process exit
wait "$pipeline_pid" 2>/dev/null || true

log_info "Workload pipeline terminated."
echo "TEARDOWN_FINISHED"
