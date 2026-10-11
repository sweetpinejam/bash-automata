# Tactical Field Manual: The Defensive Hardening Shield (`set -euo pipefail` & `ERR` Traps)

## 1. Systems Mental Model: The Default Shell's Permissive Lunacy
By default, Bash was designed in 1989 as an **interactive terminal session interpreter**, not an automated systems programming language. In interactive mode, if you mistype a command or reference a typo variable, you don't want your terminal window to abruptly close!

However, when running **unattended production automation**, these default interactive defaults are catastrophic:
1. **Silent Command Failures**: If a command fails (exit code 1 or 127), Bash continues executing subsequent lines blindly!
2. **Unbound Variable Disasters**: An undefined variable expands silently to an **empty string (`""`)**, turning `rm -rf "$TARGET_DIR/"*` into `rm -rf "/*"`!
3. **Pipeline Failure Masking**: In `cmd1 | cmd2`, the pipeline's overall exit code is determined **only by the final command `cmd2`**. If `cmd1` crashes with a core dump, Bash considers the pipeline successful if `cmd2` exits 0!

---

## 2. Syntax Anatomy: The Sacred Triad

```bash
set -euo pipefail
```

Let us dissect each flag:

### 1. `set -e` (`errexit`)
* **Behavior**: Terminates the script immediately if any pipeline or command returns a non-zero exit status.
* **Exceptions**: Does not terminate if the failing command is part of an `if` condition, `while` condition, `until` condition, or preceded by `!` or followed by `||`.

### 2. `set -u` (`nounset`)
* **Behavior**: Treats any expansion of an unset / unbound variable as a fatal error, printing an error message to `stderr` and aborting immediately.
* **Safe Fallback**: If a variable is genuinely optional, use parameter expansion fallback: `${OPTIONAL_VAR:-default}`.

### 3. `set -o pipefail`
* **Behavior**: The exit status of a pipeline is the exit status of the **last (rightmost) command that exited with a non-zero status**, or zero if all commands exited successfully.
```bash
# WITHOUT pipefail:
false | true    # Exit code: 0 (The failure of 'false' is masked!)

# WITH pipefail:
false | true    # Exit code: 1 (The failure of 'false' halts execution!)
```

---

## 3. The Production Crash Reporter: Trapping `ERR`

`set -e` aborts when an error occurs, but by default it leaves no trace of what happened. To provide instant observability in CI/CD, install an **`ERR` trap**:

```bash
on_failure() {
    local line_num="$1"
    local command="$2"
    local code="$3"

    echo "──────────────────────────────────────────────" >&2
    echo "🚨 DEPLOYMENT CRASH DETECTED" >&2
    echo "  Line Number:    $line_num" >&2
    echo "  Failed Command: $command" >&2
    echo "  Exit Code:      $code" >&2
    echo "──────────────────────────────────────────────" >&2

    cat <<EOF > "deploy_crash.dump"
CRASH_LINE=$line_num
FAILED_COMMAND=$command
EXIT_CODE=$code
TIMESTAMP=$(date +%s)
EOF
}

trap 'on_failure "$LINENO" "$BASH_COMMAND" "$?"' ERR
```

### The Magic Variables:
* **`$LINENO`**: The line number where the failure occurred.
* **`$BASH_COMMAND`**: The exact shell command or pipeline currently being executed.
* **`$?`**: The exact non-zero exit status.

---

## 4. How to Safely Ignore Expected Failures Under `set -e`

Sometimes a command is expected to return a non-zero exit code (e.g. `grep` returns 1 when no match is found, or `diff` returns 1 when files differ). How do you prevent `set -e` from killing your script?

```bash
# Pattern 1: Append '|| true':
grep "warning" system.log || true

# Pattern 2: Test directly in an if conditional:
if grep -q "warning" system.log; then
    echo "Warning found"
fi

# Pattern 3: Capture exit code:
status=0
command || status=$?
```

---

## 5. Architectural Diagram: Defensive Shield Pipeline

```
[ Execution Begins: set -euo pipefail ]
                      │
                      ▼
        [ trap 'on_failure...' ERR ]
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
[ 1. Unbound Var Check ]    [ 2. Pipefail Check ]
  echo "$REQUIRED_VAR"         cat stream | grep ...
  (Unbound? -> Abort!)        (Upstream fails? -> Abort!)
        │                           │
        └─────────────┬─────────────┘
                      ▼
         [ If ANY Unhandled Error ]
                      │
                      ▼
            [ Fire ERR Trap ]
         - Capture $LINENO, $BASH_COMMAND, $?
         - Write deploy_crash.dump
         - Exit 1
```

---

## 6. Self-Assessment Checklist
Before modifying `deploy.sh`:

1. **Why is `false | true` dangerous without `set -o pipefail`?**
   * *Answer*: Because standard Bash evaluates the pipeline exit status from the final command (`true`), masking the failure of `false`.
2. **What does `set -u` do if you reference `$UNSET_VAR`?**
   * *Answer*: It prints `unbound variable` to `stderr` and terminates the script immediately.
3. **What is stored in `$BASH_COMMAND` inside an `ERR` trap?**
   * *Answer*: The string representation of the exact shell command that triggered the error.
4. **How do you allow a command to fail without triggering `set -e`?**
   * *Answer*: By appending `|| true` or using it directly as the condition of an `if` statement.
5. **Why should `set -euo pipefail` be placed at the very top of production scripts?**
   * *Answer*: To guarantee that all subsequent lines, variable expansions, and commands are governed by strict failure defense.

---

## 7. Mission Objectives
Implement `deploy.sh` as an enterprise hardened deployment runner:
1. Place `set -euo pipefail` at the top of the script.
2. Install an `ERR` trap that calls `on_failure "$LINENO" "$BASH_COMMAND" "$?"`.
3. `on_failure` must record `CRASH_LINE`, `FAILED_COMMAND`, and `EXIT_CODE` to `deploy_crash.dump`.
4. Validate that required variables `DEPLOY_ENV` and `RELEASE_TAG` are bound; abort if unbound.
5. Execute a multi-stage validation pipeline:
   - Must fail fast if any component in a pipeline returns non-zero status.
6. When execution succeeds:
   - Generate `deploy_status.json` with status `SUCCESS`.
   - Output summary: `DEPLOY_HARDENED: env=<E>, tag=<T>, crash_trap=ACTIVE, status=SUCCESS`.
