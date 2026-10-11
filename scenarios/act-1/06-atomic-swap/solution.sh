#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: SCENARIO 1.06 (The Atomic Swap)
# ==============================================================================
# Atomic zero-downtime release deployer using kernel rename(2) semantics (mv -T).
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
# ATOMIC SWAP: Kernel-level rename(2) via mv -T
# ------------------------------------------------------------------------------
TMP_LINK="${SYMLINK_PATH}.tmp.$$"
MAIN_PID=$$
trap 'if [[ "$BASHPID" == "$MAIN_PID" ]]; then rm -f "$TMP_LINK"; fi' EXIT

log_info "Creating isolated staging symlink ($TMP_LINK)..."
ln -s "$TARGET_RELEASE" "$TMP_LINK"

log_info "Performing atomic dentry swap via mv -T (rename syscall)..."
# 'mv -T' invokes rename(2) on the destination path, ensuring continuous existence
mv -T "$TMP_LINK" "$SYMLINK_PATH"

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
