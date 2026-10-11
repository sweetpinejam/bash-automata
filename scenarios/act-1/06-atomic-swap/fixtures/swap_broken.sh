#!/usr/bin/env bash
# ==============================================================================
# SCENARIO 1.06: THE ATOMIC SWAP (Zero-Downtime Release Deployer)
# ==============================================================================
# Production blue-green deployment orchestrator for live web workloads.
# Switches the active production symlink to point to the newly prepared release.
#
# CRISIS:
# Under continuous concurrent traffic, client requests fail with transient
# 404/ENOENT errors during deployment. The legacy deployment script deletes
# the active symlink with 'rm' before creating the new one, creating a race
# window where the 'current' path ceases to exist on the filesystem!
#
# MISSION:
# Refactor the release swap logic to execute an atomic switch using kernel
# rename(2) semantics ('mv -T') so that concurrent readers never observe
# a missing path.
# ==============================================================================

set -euo pipefail

DEPLOY_ROOT="."
TARGET_RELEASE="releases/v2"
SYMLINK_PATH="current"
STATUS_FILE="deploy_status.json"

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
        --release)
            TARGET_RELEASE="$2"
            shift 2
            ;;
        --symlink)
            SYMLINK_PATH="$2"
            shift 2
            ;;
        *)
            if [[ "$1" != -* ]]; then
                TARGET_RELEASE="$1"
                shift
            else
                log_warn "Ignoring unknown option: $1"
                shift
            fi
            ;;
    esac
done

log_info "Initiating release deployment..."
log_info "Target release artifact: $TARGET_RELEASE"
log_info "Active production link:   $SYMLINK_PATH"

# ------------------------------------------------------------------------------
# Pre-flight Validation
# ------------------------------------------------------------------------------
if [[ ! -d "$TARGET_RELEASE" ]]; then
    log_error "Target release directory '$TARGET_RELEASE' does not exist!"
    exit 1
fi

if [[ ! -f "$TARGET_RELEASE/version.txt" ]]; then
    log_warn "No version.txt found in target release; deploying anyway."
fi

# ------------------------------------------------------------------------------
# BROKEN STATE: Non-Atomic Symlink Replacement
# ------------------------------------------------------------------------------
# 💥 THE DOWNTIME WINDOW:
# Deleting the active symlink leaves a race condition window where '$SYMLINK_PATH'
# does not exist in the VFS dentry cache. Concurrent file opens fail with ENOENT!
# Even 'ln -sfn' fails because GNU ln calls unlink() before symlink()!
#
# TODO: Implement atomic swap using a PID-isolated temporary symlink
#       and 'mv -T' to invoke the atomic rename(2) kernel system call.

log_info "Swapping active release to $TARGET_RELEASE..."
rm -f "$SYMLINK_PATH"
# Simulated storage micro-latency exposing race condition to readers
sleep 0.05
ln -s "$TARGET_RELEASE" "$SYMLINK_PATH"

# ------------------------------------------------------------------------------
# Post-deployment Health Check & Telemetry
# ------------------------------------------------------------------------------
if [[ -L "$SYMLINK_PATH" ]]; then
    ACTIVE_TARGET="$(readlink "$SYMLINK_PATH")"
    log_info "Deployment verified. Active symlink points to: $ACTIVE_TARGET"
    cat <<EOF > "$STATUS_FILE"
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "DEPLOYED",
  "active_target": "$ACTIVE_TARGET"
}
EOF
else
    log_error "Deployment failed: $SYMLINK_PATH is not a valid symlink!"
    exit 1
fi

echo "SWAP_COMPLETE"
