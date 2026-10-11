# Tactical Blueprint: Defensive Shield Architecture (`set -euo pipefail` & `ERR` Trap)

To harden your automation against unhandled errors, unbound variables, and silent pipeline failures, implement the following architectural patterns:

---

## 1. The Holy Trinity of Shell Hardening
Place this at the very top of your script directly below the shebang:

```bash
set -euo pipefail
```

- `-e`: Abort immediately if any simple command or pipeline returns non-zero.
- `-u`: Abort immediately if an unset/unbound variable is referenced.
- `-o pipefail`: Return the exit status of the rightmost failing command in a pipeline, rather than masking failures with the final command.

---

## 2. Crash Diagnostics with `ERR` Trap
Capture the exact line, failed command, and return code when an unhandled failure strikes:

```bash
on_failure() {
    local line_num="$1"
    local command="$2"
    local code="$3"

    echo "🚨 DEPLOYMENT CRASH DETECTED at line $line_num (command: '$command', exit: $code)" >&2

    cat <<EOF > "deploy_crash.dump"
CRASH_LINE=$line_num
FAILED_COMMAND=$command
EXIT_CODE=$code
TIMESTAMP=$(date +%s)
EOF
}

trap 'on_failure "$LINENO" "$BASH_COMMAND" "$?"' ERR
```

---

## 3. Parameter Expansion Under `set -u`
When accepting CLI arguments or environment variables under `set -u`:

```bash
# If $1 is passed, use it. Otherwise, expand $DEPLOY_ENV.
# If $DEPLOY_ENV is unset, bash will raise: 'DEPLOY_ENV: unbound variable' and halt.
DEPLOY_ENV="${1:-$DEPLOY_ENV}"
RELEASE_TAG="${2:-$RELEASE_TAG}"
```

---

## 4. Writing JSON Status Manifest via Heredoc
```bash
cat <<EOF > "deploy_status.json"
{
  "status": "SUCCESS",
  "environment": "$DEPLOY_ENV",
  "tag": "$RELEASE_TAG",
  "defensive_shield": true,
  "timestamp": $(date +%s)
}
EOF
```
