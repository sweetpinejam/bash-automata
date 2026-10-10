# Tactical Field Manual: The Exit Trap (`trap ... EXIT`)

## 1. The Mental Model (Deterministic Resource Cleanup)
In automated operations, scripts create transient resources:
- Temporary scratch files in `/tmp`
- Database transaction locks
- Background worker processes
- FIFO named pipes

If a script crashes midway due to an unexpected error (`set -e`), is terminated by a user (`Ctrl+C` / `SIGINT`), or is killed by an orchestrator (`SIGTERM`), normal sequential cleanup code at the end of the script will **NEVER execute**.
This leaves behind orphaned lockfiles that permanently deadlock future automation runs.

---

## 2. The Solution: POSIX `trap` on `EXIT`

Bash provides the **`trap`** built-in:
```bash
trap 'command_or_function' SIGNALS
```

The pseudo-signal **`EXIT`** (or `0`) is the most important signal in Linux systems engineering.
A handler trapped on `EXIT` is **guaranteed to run whenever the shell exits**, whether it exits:
1. Normally with `exit 0`
2. Prematurely due to an error under `set -e`
3. Aborted via `exit 1` or an explicit exit call
4. Terminated by unhandled errors

```bash
scratch_dir=$(mktemp -d)

cleanup() {
    rm -rf "$scratch_dir"
}
trap cleanup EXIT
```
No matter what happens during script execution, `cleanup` will run and purge the temporary directory.

---

## 3. Handling Multiple Termination Signals
While `EXIT` handles normal termination and `set -e` errors, trapping `INT` (Ctrl+C) and `TERM` (kill) ensures your trap also executes on external termination:

```bash
trap cleanup EXIT INT TERM
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `trap [-lp] [[arg] sigspec ...]`)
* Greg's Bash Wiki: [Signals and Traps](https://mywiki.wooledge.org/SignalsAndTraps)
* Google Shell Style Guide: Section 5.4 (Cleanup on Exit)

---

## 5. Mission Objective
Edit `job.sh` in your sandbox. Register a cleanup function on `EXIT` using `trap cleanup EXIT` to ensure all lockfiles and scratch directories are removed even when errors occur.
Verify with `[4] Run State Verification`.
