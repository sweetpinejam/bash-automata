# Tactical Field Manual: The Stream Contract (POSIX File Descriptors & Stream Demuxing)

## 1. Systems Mental Model: The Linux File Descriptor Table
In Unix-like operating systems, everything is a stream of bytes accessible via an integer file descriptor (**FD**). When any Linux process launches, the kernel initializes three standard file descriptors in the process's file descriptor table (`/proc/$$/fd/`):

```
┌────────────────────────────────────────────────────────┐
│             LINUX PROCESS (PID: 1000)                  │
├─────────────────┬──────────────────────────────────────┤
│ FILE DESCRIPTOR │ DEFAULT TARGET                       │
├─────────────────┼──────────────────────────────────────┤
│ 0 (stdin)       │ Keyboard / Upstream Pipe             │
│ 1 (stdout)      │ Terminal Display (Normal Data)       │
│ 2 (stderr)      │ Terminal Display (Errors & Alarms)   │
└─────────────────┴──────────────────────────────────────┘
```

### The Stream Separation Contract
A well-architected Unix program separates standard data output from diagnostic operational output:
* **FD 1 (`stdout`)**: The primary data pipeline meant for downstream consumers, parsers, and pipes.
* **FD 2 (`stderr`)**: Out-of-band operational telemetry, debug notices, errors, and progress bars.

When a junior engineer mixes both streams or dumps everything to the terminal, downstream automated consumers break or misinterpret debug logs as real data payloads.

---

## 2. Syntax Anatomy: POSIX Redirection Operators

Bash gives you direct control over the kernel file descriptor table using redirection operators:

| Operator | Action | Example |
| :--- | :--- | :--- |
| `> file` or `1> file` | Redirect FD 1 (stdout) to `file` (overwrite) | `echo "data" > out.log` |
| `>> file` or `1>> file` | Append FD 1 (stdout) to `file` | `echo "data" >> out.log` |
| `2> file` | Redirect FD 2 (stderr) to `file` (overwrite) | `cmd 2> err.log` |
| `2>> file` | Append FD 2 (stderr) to `file` | `cmd 2>> err.log` |
| `2>&1` | Duplicate FD 2 to wherever FD 1 currently points | `cmd > all.log 2>&1` |
| `&> file` | Bash shorthand for redirecting both stdout and stderr | `cmd &> all.log` |
| `< file` or `0< file` | Redirect FD 0 (stdin) from `file` | `while read line; do ... done < in.txt` |
| `3>&1` | Create custom FD 3 pointing to FD 1 | `exec 3>&1` |
| `3>&-` | Close file descriptor 3 | `exec 3>&-` |

---

## 3. The Fatal Redirection Order Trap!

The most common mistake in shell redirection is placing `2>&1` in the wrong order:

```bash
# ❌ BROKEN REDIRECTION ORDER:
command 2>&1 > output.log

# ✅ CORRECT REDIRECTION ORDER:
command > output.log 2>&1
```

### Why Order Matters to the Linux Kernel
Redirections are evaluated strictly from **left to right**:

In `command 2>&1 > output.log`:
1. First, `2>&1` evaluates: FD 2 is pointed to where FD 1 points *right now* (which is the terminal).
2. Next, `> output.log` evaluates: FD 1 is redirected to `output.log`.
3. **Result**: FD 1 writes to `output.log`, but FD 2 still prints directly to the terminal!

In `command > output.log 2>&1`:
1. First, `> output.log` evaluates: FD 1 is redirected to `output.log`.
2. Next, `2>&1` evaluates: FD 2 is pointed to where FD 1 points *now* (`output.log`).
3. **Result**: Both FD 1 and FD 2 cleanly write to `output.log`!

---

## 4. Advanced Stream Demuxing: T-Splitting Error Streams

What if you want to write standard payload to `clean.log`, write error diagnostics to `error.log`, AND simultaneously mirror error alerts to `stderr` in real time?

Using Bash process substitution with `tee`:
```bash
cmd > clean.log 2> >(tee -a error.log >&2)
```
* `> clean.log` redirects FD 1 directly to the clean data file.
* `2> >(...)` redirects FD 2 into an asynchronous `tee` subshell, which appends to `error.log` and writes back out to `>&2` (terminal stderr)!

---

## 5. Architectural Diagram: Stream Triage Sieve

```
             [ Noisy Workload Probe / Generator ]
              (Emits interleaved data and errors)
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
        [ FD 1: stdout ]            [ FD 2: stderr ]
       (Clean Payloads)           (Error Diagnostics)
             │                           │
             ▼                           ▼
    [ clean_payloads.log ]     [ error_diagnostics.log ]
             │                           │
             └─────────────┬─────────────┘
                           ▼
          [ Line & Byte Sieve Metrics ]
             - payload_lines, payload_bytes
             - error_lines, error_bytes
             - cross_contamination = false
                           │
                           ▼
          [ Emit stream_triage_report.json ]
          [ Output TRIAGE_COMPLETE Summary ]
```

---

## 6. Self-Assessment Checklist
Before modifying `triage.sh`:

1. **Which numeric file descriptor corresponds to standard error?**
   * *Answer*: File descriptor 2 (`stderr`). Standard input is 0; standard output is 1.
2. **Why does `cmd 2>&1 > file` fail to redirect stderr into `file`?**
   * *Answer*: Redirections are evaluated left to right. `2>&1` points FD 2 to the terminal before FD 1 is redirected to `file`.
3. **How do you send a message specifically to stderr inside a shell function?**
   * *Answer*: `echo "Error message" >&2`.
4. **How do you redirect stdout to file A and stderr to file B simultaneously?**
   * *Answer*: `command > fileA.log 2> fileB.log`.
5. **What does `exec 3>&1` do?**
   * *Answer*: It opens file descriptor 3 as a duplicate pointer to file descriptor 1.

---

## 7. Mission Objectives
Implement `triage.sh` as a production stream splitter and telemetry sieve:
1. Accept CLI arguments:
   `./triage.sh [--tee-errors] [--stdout-log <file>] [--stderr-log <file>]`
   Default `stdout_log`: `clean_payloads.log`
   Default `stderr_log`: `error_diagnostics.log`
2. Run the probe workload: separate FD 1 into `<stdout_log>` and FD 2 into `<stderr_log>`.
3. If `--tee-errors` is passed: mirror stderr to terminal while writing to `<stderr_log>`.
4. Measure metrics:
   - `PAYLOAD_LINES`, `PAYLOAD_BYTES`
   - `ERROR_LINES`, `ERROR_BYTES`
5. Assert zero cross-contamination:
   - `<stdout_log>` must contain zero `ERROR:` lines.
   - `<stderr_log>` must contain zero `DATA:` lines.
6. Generate `stream_triage_report.json` with metrics and status `TRIAGED`.
7. Output summary: `TRIAGE_COMPLETE: payload_lines=<N>, error_lines=<M>, clean_log=<clean>, error_log=<err>`.
