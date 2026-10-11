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
  * Every lesson includes a **1-page Field Manual (`lesson.md`)** with reading references, mental models, and cheatsheets (`[1]`).
  * Every lesson includes **progressive tactical hints (`[6]`)**.
  * Every lesson includes a **targeted code blueprint & almost-answer (`almost_answer.md` / `[7]`)** providing syntax skeletons without spoiling the full sandbox script.
  * Every lesson includes the **full reference working solution and post-mortem (`solution.sh` / `[8]`)**.

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
  * `2.01: The Token Bucket Semaphore` — Limiting parallel subshell concurrency to $N=4$ slots using a FIFO token bucket without `xargs`.
  * `2.02: The Runaway Worker Pool` — Dynamic job queue draining with `wait -n` worker slot replenishment and sentinel shutdown tokens.
  * `2.03: The Flaking Healthcheck Latch` — Consecutive failure threshold sliding window in pure Bash to avoid premature rollback on transient blips.
  * `2.04: The Unix Socket Handoff` — Safe atomic Unix domain socket (`/tmp/*.sock`) lifecycle management and pre-flight validation.
  * `2.05: The Parallel Map-Reduce Stream` — Partitioned concurrent background mapping with PID array tracking and barrier reduction.
  * `2.06: The Self-Healing Watchdog Heartbeat` — Timestamp staleness detection (`$(( $(date +%s) - ts )) > threshold`) with auto-recovery and forced SIGKILL escalation.
  * `2.07: The Two-Way Coprocess Dialogue` — Interactive protocol negotiation using Bash `coproc` file descriptors `${NAME[0]}` and `${NAME[1]}` without pipe stalls.
  * `2.08: The Cascading Timeout Shield` — Subprocess execution watchdog with subshell timers and signal cancellation to prevent cascading thread starvation.
  * `2.09: The Advisory Lock Contest` — Preventing concurrent database corruption using Linux kernel `flock(1)` on dedicated file descriptors (`exec 200>`).
  * `2.10: The Graceful Drain Teardown` — Kubernetes-style pod teardown: trapping `SIGTERM`, setting a draining latch, finishing active in-flight jobs, and exiting cleanly.

* **Track 3: The Dynamic Duo (Bash + Python Stream Synergy)** (Missions 3.01 – 3.10)
  * `3.01: The JSON Stream Pipeline` — High-velocity NDJSON parsing piping Bash stream into zero-dep Python `sys.stdin` stream processors.
  * `3.02: The Prometheus Metric Exporter` — Pure Bash + Python endpoint converting internal service logs into OpenMetrics exposition format.
  * `3.03: The CSV Multi-Column Aggregator` — Large-scale log metric summarization bypassing slow subshell loops.
  * `3.04: The Config Schema Validator` — Pre-flight schema validation before deployment execution.
  * `3.05: The Tar Streaming Filter` — Filtering and inspecting tar archive streams on the fly without extracting to disk.
  * `3.06: The Socket Ping-Pong Service` — Simulated microservice RPC communication over localhost TCP ports.
  * `3.07: The Event Dispatch Bus` — Pub/sub message fan-out using named pipes and Python subscribers.
  * `3.08: The Rate-Limiting Leaky Bucket` — Ingest throttling with sub-millisecond delay control.
  * `3.09: The Log Redaction Pipeline` — Streaming PII/Secret scrubber with zero disk leak.
  * `3.10: The Dynamic Config Hot-Reload` — In-flight JSON configuration reload across active running daemons.

* **Track 4: Simulated Web, Sockets & DevOps** (Missions 4.01 – 4.10)
  * `4.01: The Mock HTTP Gateway` — Pure `/dev/tcp` or Python socket lightweight HTTP health responder.
  * `4.02: The Blue-Green Traffic Switcher` — Reverse proxy upstream config re-pointing and reload.
  * `4.03: The SSL Certificate Expiry Alert` — Automated TLS certificate inspection and metric emission.
  * `4.04: The Slowloris Connection Reaper` — Detecting and killing stale half-open TCP connections.
  * `4.05: The Database Migration Guard` — Pre-migration lock acquisition, schema verification, and rollback safety.
  * `4.06: The Disk Space Quota Warden` — Automated emergency log rotation when partition usage exceeds 90%.
  * `4.07: The Distributed Trace Propagator` — Passing `TRACE_ID` headers across piped service invocations.
  * `4.08: The Git Hook Safety Latch` — Zero-external-dependency pre-push verification and secret detection.
  * `4.09: The Mock Webhook Relayer` — Resilient HTTP POST event webhook dispatcher with retry queue.
  * `4.10: The Incident Post-Mortem Scribe` — Automated incident artifact bundler generating Markdown post-mortems.

* **Track 5: Algorithmic Automation & Intelligent Systems** (Missions 5.01 – 5.10)
  * `5.01: The Dependency DAG Resolver` — Topological sort of build tasks in pure Bash and Python.
  * `5.02: The Binary Search Log Bisect` — Finding the exact commit/log timestamp of regression via bisect automation.
  * `5.03: The Anomaly Spike Detector` — Statistical standard deviation calculation over time-series metric logs.
  * `5.04: The Consistent Hash Load Balancer` — Deterministic request routing to mock backend nodes.
  * `5.05: The Sliding Window Rate Limiter` — Millisecond-resolution sliding window request counter.
  * `5.06: The Memory Heap Leak Profiler` — Tracking process RSS growth in `/proc/$PID/statm` over time.
  * `5.07: The Automated Rollback Heuristic` — Evaluating error budget burn rate to trigger auto-rollback.
  * `5.08: The Chaos Engineering Fault Injector` — Injecting packet delay, SIGSTOP, and disk fills into running services.
  * `5.09: The Secret Zeroization Bot` — Scrubbing sensitive environment variables and memory files from worker dumps.
  * `5.10: The Autonomous Incident Commander` — Multi-step incident diagnosis, triage, remediation, and verification orchestrator.

---

## 5. Architectural Standards for Advanced Acts (Acts 2 – 5)

To maintain realistic engineering depth without bloated boilerplate:

1. **Multi-Component Architecture**:
   Each scenario includes 2–3 cooperating components (e.g. background supervisor daemon, mock workload generator, health probe).
2. **Realistic Symptoms over Script Toys**:
   Briefings describe real infrastructure alarms (rate-limit 429s, deadlock freezes, zombie leaks). Trainees inspect live processes, logs, and state files.
3. **Smart, Surgical Fixes**:
   Fixes focus on resilient systems engineering primitives (kernel syscalls, concurrency primitives, atomic operations, signals).
4. **Four-Tier Learning Hierarchy**:
   Every scenario provides:
   - `[1] Field Manual (`lesson.md`)` — Deep mental models, architecture ASCII diagram, POSIX mechanics.
   - `[6] Tactical Intel` — 3 progressive hints.
   - `[7] Code Blueprint (`almost_answer.md`)` — Targeted syntax pattern and mechanics.
   - `[8] Reference Solution (`solution.sh`)` — Complete working code and post-mortem analysis.
