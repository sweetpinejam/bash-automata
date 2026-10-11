# Tactical Field Manual: The Exit Trap & Deterministic Sandbox Cleanup (`trap ... EXIT`)

## 1. Systems Mental Model: The Phantom Clutter Epidemic
In automated systems engineering, scripts constantly provision transient resources:
* Isolated temporary build sandboxes (`/tmp/build.XXXXXX` or `./.scratch_$$`)
* Process mutex lockfiles (`worker.pid`, `deploy.lock`)
* Transient FIFO named pipes and socket tunnels
* Database transaction staging tables

In a naive script, developers write cleanup instructions at the very bottom:
```bash
# NAIVE & DANGEROUS:
scratch=$(mktemp -d)
perform_build "$scratch"
rm -rf "$scratch"  # <--- ONLY runs if nothing fails above!
```

### Why Naive Sequential Cleanup Fails:
If **ANYTHING** goes wrong between creation and the final line:
1. An unhandled command fails under `set -e`
2. An unbound variable explodes under `set -u`
3. A pipeline crashes under `set -o pipefail`
4. The user hits `Ctrl+C` (`SIGINT`)
5. A Kubernetes orchestrator sends `SIGTERM` before pod eviction
6. The process runs out of memory (`SIGKILL` cannot be trapped, but all graceful signals can)

The execution jumps straight to process termination, bypassing sequential `rm -rf` entirely.
Over days and weeks in production:
* Disk space fills up with gigabytes of abandoned build artifacts.
* Abandoned lockfiles permanently deadlock subsequent automated jobs.
* Systems administrators get paged at 03:00 to run manual cleanup.

---

## 2. Syntax Anatomy: The POSIX `trap` Built-in

```bash
trap 'command_or_handler' SIGNAL_LIST
```

Bash maintains an internal signal disposition table. When a monitored signal is caught, Bash suspends current execution and runs the registered trap string.

### The Sacred Pseudo-Signal: `EXIT` (Signal 0)
`EXIT` is **not an OS kernel signal**. It is a shell pseudo-signal that is guaranteed to fire **whenever the shell process exits**, including:
1. Normal script completion (`exit 0` or falling off the end of the script).
2. Explicit premature aborts (`exit 1`, `exit 42`).
3. Fatal errors triggered by `set -e`, `set -u`, or `set -o pipefail`.

### Comprehensive Signal Binding: `EXIT INT TERM`
While `EXIT` handles errors and script exits, trapping `INT` (terminal interrupt / `Ctrl+C`) and `TERM` (kill / orchestrator shutdown) guarantees cleanup even under external cancellation:

```bash
trap cleanup EXIT INT TERM
```

---

## 3. Production Hardening: The Robust Cleanup Handler

Writing a production-grade cleanup handler requires defensive discipline:

```bash
# Guard 1: Initialize resource pointers to empty strings BEFORE registering trap
SCRATCH_DIR=""
PID_FILE=""

cleanup() {
    # Guard 2: Capture the true exit status before any cleanup command overwrites $?
    local exit_status=$?

    # Guard 3: NEVER run rm -rf on an unbound or empty variable!
    if [[ -n "${SCRATCH_DIR:-}" && -d "$SCRATCH_DIR" ]]; then
        echo "[CLEANUP] Removing transient sandbox: $SCRATCH_DIR" >&2
        rm -rf "$SCRATCH_DIR"
    fi

    if [[ -n "${PID_FILE:-}" && -f "$PID_FILE" ]]; then
        echo "[CLEANUP] Removing PID lock: $PID_FILE" >&2
        rm -f "$PID_FILE"
    fi

    # Guard 4: Propagate the original exit status
    exit "$exit_status"
}

trap cleanup EXIT INT TERM
```

### Crucial Defensive Rules:
1. **Never `rm -rf "$VAR"` without validating `$VAR` is non-empty**:
   If `$VAR` is unset or empty, `rm -rf "$VAR/*"` evaluates to `rm -rf "/*"`!
2. **Preserve `$?`**:
   The very first line of `cleanup()` must be `local exit_status=$?`. If you run `echo` or `rm` first, `$?` will be reset to 0, hiding previous failures from the operating system!
3. **Register the trap BEFORE creating the resource**:
   If you create the file first and crash on the next line before registering the trap, the resource leaks. Register the trap first.

---

## 4. Architectural Diagram: Lifecycle of an Exit Trap

```
  [ Script Starts ]
         │
         ▼
  [ Define Empty Variables: SCRATCH_DIR="", PID_FILE="" ]
         │
         ▼
  [ Register Trap: trap cleanup EXIT INT TERM ]
         │
         ▼
  [ Provision Scratch: SCRATCH_DIR=$(mktemp -d) ]
         │
  ┌──────┴──────────────────────────┐
  │                                 │
  ▼                                 ▼
[ Normal Processing ]     [ Unexpected Crash or Signal ]
  - Task succeeds           - Command failure (set -e)
  - Result generated        - Orchestrator SIGTERM
  │                         - User Ctrl+C (SIGINT)
  │                                 │
  └──────────────┬──────────────────┘
                 │
                 ▼
       [ TRAP FIRES: cleanup() ]
       ├── Capture $exit_status
       ├── Check -d "$SCRATCH_DIR" -> rm -rf
       ├── Check -f "$PID_FILE"    -> rm -f
       └── exit "$exit_status"
                 │
                 ▼
     [ Zero Disk Pollution: Guaranteed ]
```

---

## 5. Self-Assessment Checklist
Before modifying `job.sh`:

1. **Why does `rm -rf "$scratch"` at the end of a script fail in CI/CD pipelines?**
   * *Answer*: Because any preceding failure under `set -e` or any `SIGTERM` terminates the process immediately, skipping all subsequent lines.
2. **When does a trap registered on `EXIT` execute?**
   * *Answer*: Whenever the shell process exits for any reason (clean exit, explicit `exit N`, or fatal error).
3. **Why should `local exit_status=$?` be the very first line inside `cleanup()`?**
   * *Answer*: Because any command executed inside the function (like `echo` or `rm`) will overwrite `$?` with its own exit code.
4. **What disaster happens if `cleanup()` runs `rm -rf "$SCRATCH_DIR/"*` while `SCRATCH_DIR` is empty or unbound?**
   * *Answer*: It expands to `rm -rf "/*"`, wiping the root filesystem.
5. **Why should you register `trap cleanup EXIT INT TERM` before provisioning the directory?**
   * *Answer*: To prevent a race condition where the process dies immediately after directory creation but before the trap handler is attached.

---

## 6. Mission Objectives
Implement `job.sh` as an atomic zero-pollution worker sandbox runner:
1. Enable `set -euo pipefail`.
2. Define `cleanup()` to safely purge `$SCRATCH_DIR` and `$PID_FILE` if they exist, preserving exit code.
3. Register the trap on `EXIT`, `INT`, and `TERM`.
4. Provision an isolated temporary scratch directory:
   `SCRATCH_DIR="$(mktemp -d "./.sandbox_XXXXXX")"`
5. Write current PID `$$` to `$PID_FILE` (`$SCRATCH_DIR/worker.pid` and `./active_job.pid`).
6. Perform multi-stage sandbox processing:
   - Stage 1: Generate temporary config and assets inside `$SCRATCH_DIR`.
   - Stage 2: Support `--simulate-crash` (intentionally fail) and `--hold` (sleep 5 seconds to test signals).
   - Stage 3: Produce `./job_manifest.json` on success outside the scratch directory.
7. Output summary: `JOB_EXECUTED: pid=<PID>, scratch=<DIR>, status=SUCCESS`.
