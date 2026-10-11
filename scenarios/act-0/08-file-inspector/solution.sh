#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.08 (The File Inspector)
# ==============================================================================
set -euo pipefail

REPORT_FILE="health_report.json"

if [[ "${1:-}" == "--report" ]]; then
    REPORT_FILE="${2:-}"
    [[ -n "$REPORT_FILE" ]] || { echo "Error: Missing report file path" >&2; exit 1; }
    shift 2
fi

PASSED_CHECKS=0
FAILED_CHECKS=0
FIRST_FAILURE=""

run_check() {
    local check_name="$1"
    local passed="$2"
    local description="$3"

    if [[ "$passed" -eq 1 ]]; then
        echo "  [PASS] $description"
        (( ++PASSED_CHECKS ))
    else
        echo "  [FAIL] $description"
        (( ++FAILED_CHECKS ))
        if [[ -z "$FIRST_FAILURE" ]]; then
            FIRST_FAILURE="$check_name"
        fi
    fi
}

# Check 1: config_integrity
if [[ -f "config/app.conf" && -s "config/app.conf" && -r "config/app.conf" ]]; then
    run_check "config_integrity" 1 "config/app.conf is valid and readable"
else
    run_check "config_integrity" 0 "config/app.conf missing, empty, or unreadable"
fi

# Check 2: release_dir_writable
if [[ -d "releases" && -w "releases" ]]; then
    run_check "release_dir_writable" 1 "releases/ is a writable directory"
else
    run_check "release_dir_writable" 0 "releases/ missing or not writable"
fi

# Check 3: binary_executable
if [[ -f "bin/app" && -x "bin/app" ]]; then
    run_check "binary_executable" 1 "bin/app is an executable regular binary"
else
    run_check "binary_executable" 0 "bin/app missing or not executable"
fi

# Check 4: symlink_integrity (no dangling symlink)
if [[ -L "current_release" && -e "current_release" ]]; then
    run_check "symlink_integrity" 1 "current_release points to a valid release target"
else
    run_check "symlink_integrity" 0 "current_release is missing, not a symlink, or dangling"
fi

# Check 5: logs_dir_writable
if [[ -d "logs" && -w "logs" ]]; then
    run_check "logs_dir_writable" 1 "logs/ is a writable log directory"
else
    run_check "logs_dir_writable" 0 "logs/ missing or not writable"
fi

# Write JSON report
OVERALL_STATUS="FAILED"
if (( FAILED_CHECKS == 0 )); then
    OVERALL_STATUS="PASSED"
fi

cat <<EOF > "$REPORT_FILE"
{
  "status": "$OVERALL_STATUS",
  "total_checks": 5,
  "passed_checks": $PASSED_CHECKS,
  "failed_checks": $FAILED_CHECKS
}
EOF

# Output verdict
if (( FAILED_CHECKS == 0 )); then
    echo "ALL_CHECKS_PASSED"
    exit 0
else
    echo "PREFLIGHT_FAILED: $FIRST_FAILURE"
    exit 1
fi
