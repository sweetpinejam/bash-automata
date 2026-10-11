#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.08: The File Inspector (Filesystem Pre-Flight Auditor)
# ==============================================================================
# INSTRUCTIONS:
# Implement a comprehensive deployment pre-flight health auditor in pure Bash.
#
# Requirements:
# 1. Parse optional `--report <file>` argument (default: "health_report.json").
# 2. Run 5 required filesystem health checks:
#    - Check 1 (config_integrity):
#        "config/app.conf" exists (-f), is non-empty (-s), and is readable (-r).
#    - Check 2 (release_dir_writable):
#        "releases" exists (-d) and is writable (-w).
#    - Check 3 (binary_executable):
#        "bin/app" exists (-f) and is executable (-x).
#    - Check 4 (symlink_integrity):
#        "current_release" is a symlink (-L) AND its target exists (-e).
#        Detect dangling symlinks!
#    - Check 5 (logs_dir_writable):
#        "logs" exists (-d) and is writable (-w).
# 3. For each check:
#    - Output "[PASS] <message>" or "[FAIL] <message>".
# 4. Generate "<report_file>" formatted as JSON:
#    {
#      "status": "PASSED" | "FAILED",
#      "total_checks": 5,
#      "passed_checks": <count>,
#      "failed_checks": <count>
#    }
# 5. Exit code:
#    - Exit 0 if all 5 pass, printing "ALL_CHECKS_PASSED"
#    - Exit 1 if any fail, printing "PREFLIGHT_FAILED: <first_failed_check>"
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
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  [FAIL] $description"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        if [[ -z "$FIRST_FAILURE" ]]; then
            FIRST_FAILURE="$check_name"
        fi
    fi
}

# --- STEP 1: EXECUTE HEALTH CHECKS ---

# TODO: Check 1 (config_integrity)
# "config/app.conf" exists (-f), has size > 0 (-s), and is readable (-r)


# TODO: Check 2 (release_dir_writable)
# "releases" exists as a directory (-d) and is writable (-w)


# TODO: Check 3 (binary_executable)
# "bin/app" exists as a regular file (-f) and is executable (-x)


# TODO: Check 4 (symlink_integrity)
# "current_release" is a symbolic link (-L) AND points to an existing target (-e)
# Beware: if -L is true but ! -e, it is a dangling symlink!


# TODO: Check 5 (logs_dir_writable)
# "logs" exists as a directory (-d) and is writable (-w)


# --- STEP 2: WRITE JSON HEALTH REPORT ---
OVERALL_STATUS="FAILED"
if [[ "$FAILED_CHECKS" -eq 0 ]]; then
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

# --- STEP 3: EXIT VERDICT ---
if [[ "$FAILED_CHECKS" -eq 0 ]]; then
    echo "ALL_CHECKS_PASSED"
    exit 0
else
    echo "PREFLIGHT_FAILED: $FIRST_FAILURE"
    exit 1
fi
