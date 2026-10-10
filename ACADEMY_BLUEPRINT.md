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

## 3. The 15-Lesson Starter Bootcamp (Traditional Bash, Spiced Up)

* **Module 1: Variables, Quoting & String Surgery**
  * `0.01: The Space Landmine` — Word-splitting & unquoted variables in automated cleanup bots.
  * `0.02: Default Fallbacks & Guards` — Parameter expansion defaults (`${VAR:-default}`, `${VAR:?error}`).
  * `0.03: The String Surgeon` — Stripping paths & extensions in-memory (`${VAR##*/}`, `${VAR%.*}`).
  * `0.04: Pure In-Memory Replace` — Text substitution with `${VAR//bad/good}` without spawning `sed`.
* **Module 2: Conditionals, Numbers & Comparisons**
  * `0.05: The Bracket Duel` — Why `[` crashes on empty strings, and why modern `[[ ]]` wins.
  * `0.06: Integer Arithmetic` — Arithmetic expansion `(( x = a + b ))`, `(( count++ ))` vs `expr`.
  * `0.07: Pattern Matching in [[ ]]` — Glob matching `[[ $FILE == *.log ]]` and regex `[[ $IP =~ ^[0-9]+ ]]`.
* **Module 3: Control Flow & Safe Loops**
  * `0.08: Stream-Safe While Loops` — Reading lines cleanly with `while IFS= read -r line`.
  * `0.09: The Subshell Ghost` — Why piping into loops erases variables, and fixing with `< <(cmd)`.
  * `0.10: The Command Dispatcher` — Clean multi-branch routing with `case "$ACTION" in ... esac`.
* **Module 4: Functions & Scoping Discipline**
  * `0.11: The Variable Leak` — Preventing global scope pollution using `local`.
  * `0.12: Flag & Argument Parsing` — Handling `$1`, `$2`, `$#`, and stepping through flags with `shift`.
  * `0.13: Short-Circuit Guard Rails` — Replacing 10-line if-trees with `command || { exit 1; }`.
* **Module 5: Streams, Traps & Exit Codes**
  * `0.14: Heredoc Template Forge` — Generating clean multi-line configs with `cat <<'EOF' > app.conf`.
  * `0.15: The Exit Code Contract` — Explicit error signaling with `exit 0/1/2` and reading `$?`.

---

## 4. The 50-Lesson Master Curriculum (The 5 Tracks)

* **Track 1: POSIX Shell & Systems Plumbing** (Lessons 01 – 10)
* **Track 2: Process Control, Concurrency & IPC** (Lessons 11 – 20)
* **Track 3: The Dynamic Duo (Bash + Python Stream Synergy)** (Lessons 21 – 30)
* **Track 4: Simulated Web, Sockets & DevOps** (Lessons 31 – 40)
* **Track 5: Algorithmic Automation & Intelligent Systems** (Lessons 41 – 50)
