#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.07: THE SHARED MEMORY BUS (High-Throughput Telemetry Emitter)
# ==============================================================================
# Production sensor telemetry daemon emitting high-frequency system snapshots.
#
# CRISIS:
# The daemon writes metrics frames to a physical disk file ('disk_telemetry.dat')
# in the current workspace directory. Storage controller I/O queueing, VFS inode
# journaling, and dirty-page flushes throttle write throughput, causing consumer
# deadlines to time out.
#
# MISSION:
# Relocate the telemetry stream buffer directly into Linux kernel shared memory
# (/dev/shm/telemetry_bus.dat) to achieve sub-millisecond RAM bus throughput.
# Implement a defensive EXIT trap to unlink the buffer node upon termination to
# prevent leaking RAM in tmpfs.
# ==============================================================================

set -euo pipefail

TOTAL_FRAMES=100
INTERVAL=0.005
# BROKEN STATE: Writing to workspace storage incurs physical filesystem I/O latency!
BUS_FILE="disk_telemetry.dat"

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
        --frames)
            TOTAL_FRAMES="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --bus)
            BUS_FILE="$2"
            shift 2
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                TOTAL_FRAMES="$1"
                shift
            else
                shift
            fi
            ;;
    esac
done

log_info "Initializing telemetry emitter (PID: $$)..."
log_info "Target metrics buffer: $BUS_FILE"
log_info "Target frame count:    $TOTAL_FRAMES"

# ------------------------------------------------------------------------------
# BROKEN STATE: Storage I/O Bottleneck & Missing RAM Cleanup Trap
# ------------------------------------------------------------------------------
# 💥 THE DEFECT:
# 1. Writing to a disk-backed path incurs physical block layer journaling.
# 2. Files written to Linux shared memory (/dev/shm) persist in volatile RAM
#    even after process termination unless unlinked via 'trap ... EXIT'!
#
# TODO:
# 1. Set BUS_FILE="/dev/shm/telemetry_bus.dat"
# 2. Register EXIT cleanup trap: trap 'rm -f "$BUS_FILE"' EXIT INT TERM

# ------------------------------------------------------------------------------
# High-Frequency Emission Loop
# ------------------------------------------------------------------------------
for (( i=1; i<=TOTAL_FRAMES; i++ )); do
    # Sample host load metrics
    LOAD_VAL=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0.15")
    UPTIME_VAL=$(awk '{print $1}' /proc/uptime 2>/dev/null || echo "1234.5")

    # Write telemetry frame to the buffer
    echo "FRAME_$i load=$LOAD_VAL uptime=$UPTIME_VAL temp=42C" > "$BUS_FILE"
    sleep "$INTERVAL"
done

log_info "Completed streaming $TOTAL_FRAMES telemetry frames."
echo "WRITER_FINISHED"
