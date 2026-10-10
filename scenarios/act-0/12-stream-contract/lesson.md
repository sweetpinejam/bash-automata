# Tactical Field Manual: The Stream Contract

## 1. The Mental Model (How Linux Thinks)
In Unix and POSIX operating systems, every process communicates through numbered byte streams called **File Descriptors (FDs)**:
* `FD 0 (stdin)`: Standard Input (reads bytes from your keyboard or upstream pipe).
* `FD 1 (stdout)`: Standard Output (writes clean, structured data).
* `FD 2 (stderr)`: Standard Error (writes diagnostics, progress logs, and panic messages).

By default, both `stdout` (FD 1) and `stderr` (FD 2) point to your terminal screen (`/dev/pts/*`). This causes data and errors to mix together on your console.

## 2. Redirection Cheatsheet
Redirection operators rewire where a file descriptor points before the command executes:
```bash
# Redirect standard output (FD 1) to a file (overwriting)
command > output.log

# Append standard output to a file
command >> output.log

# Redirect standard error (FD 2) to a file
command 2> error.log

# Silence error diagnostics completely (the black hole)
command 2> /dev/null

# Separate clean data from error diagnostics simultaneously
command > data.log 2> error.log

# Combine both stdout and stderr into the SAME file
command > all.log 2>&1
```

## 3. Deadly Pitfall: Pipeline Leakage
In Bash pipelines (`cmd1 | cmd2`), **only standard output (FD 1) travels through the pipe!**
* `stderr` completely bypasses the pipe and crashes onto your terminal screen.
* If an error message accidentally leaks into stdout, downstream parsers (like Python `json.load()`) will crash with syntax errors.

## 4. Recommended Reading List
Before executing this drill, review:
* `man 1 bash` (Search for section: `REDIRECTION`)
* GNU Bash Reference: Section 3.6 (Redirections)
* POSIX IEEE Std 1003.1: Standard File Descriptors

## 5. Mission Objective
Edit `triage.sh` to route clean metrics into `clean.log` and error alerts into `error.log`.
```bash
simulate_noisy_probe > clean.log 2> error.log
```
