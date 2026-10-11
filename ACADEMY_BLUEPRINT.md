# Bash Automata: Academy Blueprint & Governing Rules

> **Interactive Systems & Agent Learning Engine**  
> *Architectural Blueprint, Pedagogical Principles & Master Curriculum*

---

## 1. Core Engineering Rules & Contracts

Every script, scenario, and tool in this platform strictly adheres to these five governing laws:

1. **The 15-Line Rule**:
   Bash scripts must stay under 15 lines. If an operation requires dictionaries, complex arithmetic, heavy regex, or nested data structures, pipe the stream into Python.
2. **The Stream Contract**:
   Bash and Python communicate strictly via standard POSIX streams: `stdout` $\rightarrow$ `stdin`.
3. **The Defensive Shell**:
   Every Bash script begins with `set -euo pipefail`. Scripts must never silently continue on error or expand unbound variables.
4. **Zero-Pollution & Fast Execution**:
   Work executes inside disposable sandboxes (`~/.automata/sandboxes/<id>/workspace`). Execution and verification must complete in under 2 seconds. Instant rollback (`automata reset`) takes under 2 seconds.
5. **Zero External Dependencies**:
   The entire CLI engine, SQLite progress ledger, and adaptive sandbox drivers use the **Python 3.12 Standard Library only**.

---

## 2. Pedagogical Principles (The Mentor Contract)

* **No Obsolete Syntax**: We do not teach archaic 1980s trivia, ancient `awk` gymnastics, or passive memorization. We teach modern, resilient Linux systems engineering.
* **De-Mining Exercises**: Syntax is never taught in a vacuum. Every drill is a live production scenario (e.g., a broken automated cleanup bot, a leaking descriptor, or a silent deadlock).
* **The "Never Get Stuck" Rule**:
  * Every lesson includes a **1-page Field Manual (`lesson.md`)** with reading references, mental models, and cheatsheets.
  * Every lesson includes **progressive tactical hints (`[6]`)**.
  * Every lesson includes the **reference working solution and post-mortem (`[7]`)**.

---

## 3. The 20-Lesson Starter Bootcamp (Core Bash + Applied Automation)

* **Module 1: Variables, Quoting & String Surgery**
  * `0.01: The Space Landmine` — Word-splitting & unquoted variables in automated cleanup bot.
  * `0.02: Default Fallbacks & Guards` — Parameter expansion defaults (`${VAR:-default}`, `${VAR:?error}`) in an env/config injector.
  * `0.03: The String Surgeon` — In-memory path and extension stripping (`${VAR##*/}`, `${VAR%.*}`) for automated artifact sorting.
  * `0.04: Pure In-Memory Replace` — Bulk sanitization with `${VAR//bad/good}` without spawning slow `sed` subprocesses.

* **Module 2: Conditionals, Numbers & File Tests**
  * `0.05: The Bracket Duel` — Why `[` crashes on empty strings, and why modern `[[ ]]` wins for automated validation.
  * `0.06: Integer Arithmetic` — Arithmetic expansion `(( x = a + b ))`, `(( count++ ))` for metric aggregation vs subshell fork bombs.
  * `0.07: Pattern Matching in [[ ]]` — Glob matching `[[ $FILE == *.log ]]` and regex `[[ $IP =~ ^[0-9]+ ]]` in an automated log classifier.
  * `0.08: The File Inspector` — Automated filesystem health checks using `-f`, `-d`, `-s`, `-x` test operators.

* **Module 3: Control Flow, Safe Loops & Streams**
  * `0.09: Stream-Safe While Loops` — Reading lines cleanly with `while IFS= read -r line` without trimming spaces or backslashes.
  * `0.10: The Subshell Ghost` — Why piping into loops erases variables, and fixing with `< <(cmd)` process substitution.
  * `0.11: The Command Dispatcher` — Clean multi-branch CLI command routing with `case "$ACTION" in ... esac`.
  * `0.12: The Stream Contract` — Splitting stdout `>` and stderr `2>` streams cleanly to prevent downstream triage contamination.

* **Module 4: Functions, Scoping & Argument Discipline**
  * `0.13: The Variable Leak` — Preventing global scope pollution in automation libraries using `local`.
  * `0.14: Flag & Argument Parsing` — Handling `$1`, `$2`, `$#`, and stepping through flags with `shift`.
  * `0.15: Short-Circuit Guard Rails` — Replacing verbose if-trees with `command || { exit 1; }` fail-fast patterns.
  * `0.16: The Defensive Shield` — Bulletproofing scripts against silent failures with `set -euo pipefail`.

* **Module 5: Resilient Automation & Systems Traps**
  * `0.17: The Exit Trap & Cleanup` — Guaranteeing sandbox zero-pollution with `trap 'cleanup' EXIT`.
  * `0.18: The Lockfile Mutex` — Preventing duplicate bot runs with atomic directory locking (`mkdir`).
  * `0.19: The Exponential Backoff Retry Loop` — Automated polling with exponential sleep backoff against flaky services.
  * `0.20: Heredoc Template Forge` — Dynamically generating complex config files safely with `cat <<'EOF' > config`.

---

## 4. The 50-Lesson Master Curriculum (The 5 Tracks)

* **Track 1: POSIX Shell & Systems Plumbing** (Missions 1.01 – 1.10 - LIVE & PLAYABLE)
  * `1.01: The Choked Pipe` — 5,000 req/s stream decoupling via named pipes (`mkfifo`) and binary buffering under 64MB RAM.
  * `1.02: The Leaking Descriptor` — Custom file descriptor lifecycle (`exec {fd}<...`, `exec {fd}<&-`) to defeat `ulimit -n` table leaks.
  * `1.03: The Silent Deadlock` — Resolving circular FIFO blocking deadlocks in bidirectional Python-Bash handshakes.
  * `1.04: The Phantom Signal` — Zero-downtime hot reloading (`SIGHUP`) and on-demand telemetry dumps (`SIGUSR1`).
  * `1.05: The Orphan Graveyard` — Reaping zombie processes (`[defunct]`) using active `wait` / `wait -n` supervisor reapers.
  * `1.06: The Atomic Swap` — Zero-downtime blue-green release swapping using atomic kernel `rename(2)` (`mv -T`).
  * `1.07: The Shared Memory Bus` — High-speed sub-millisecond IPC over `/dev/shm` tmpfs RAM disk with zero storage I/O.
  * `1.08: The Subreaper Tree` — Cascading process tree termination (`pkill -P`) to eradicate orphaned grandchild processes.
  * `1.09: The Unbuffered Stream` — Defeating libc 4KB stdio block-buffering latency stalls using line-buffering (`stdbuf -oL`, `--line-buffered`).
  * `1.10: The Kernel Cgroup Throttle` — Preventing OOM killer slaughter under 32MB cgroups using O(1) constant-memory streaming pipelines.
* **Track 2: Process Control, Concurrency & IPC** (Missions 2.01 – 2.10)
* **Track 3: The Dynamic Duo (Bash + Python Stream Synergy)** (Missions 3.01 – 3.10)
* **Track 4: Simulated Web, Sockets & DevOps** (Missions 4.01 – 4.10)
* **Track 5: Algorithmic Automation & Intelligent Systems** (Missions 5.01 – 5.10)
