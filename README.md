# Bash Automata

> **Autonomous Infrastructure Workbench & Incident Simulation Wargame**

[![CI Engine & Scenario Verification](https://github.com/sweetpinejam/bash-automata/actions/workflows/ci.yml/badge.svg)](https://github.com/sweetpinejam/bash-automata/actions/workflows/ci.yml)
[![Python 3.12](https://img.shields.io/badge/python-3.12%2B-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 1. Core Philosophy

**Bash Automata** is not a passive syntax tutorial, a web-based Bash cheat sheet, or a browser-mocked terminal emulator. It is an authentic, hands-on Linux incident simulator and infrastructure automation harness designed around real system state, real failure modes, and real code execution.

### The Dynamic Duo (Bash + Python)
* **Bash is the Nervous System**: Handles POSIX process supervision, exit trapping (`trap ... EXIT INT TERM`), file descriptors, named pipes (`mkfifo`), stream multiplexing, and inotify event loops (<15 lines).
* **Python is the Brain**: Handles async sockets, complex algorithmic triage, payload verification, structured data transformations, and HTTP services.

---

## 2. Adaptive Runtime Engine

Each incident scenario executes inside an isolated adaptive runtime environment:
1. **Adaptive Driver Model**: Dynamically provisions between **Local Sandboxes** (isolated process namespaces & scrubbed environments) and **Docker Containers** (strict cgroups v2 resource clamping: `memory.max`, `cpu.max`, `pids.max`).
2. **State-Driven Verification**: Solutions are never graded on command history or text matching. The verification engine executes real functional assertions (`verify.py`) directly against live system state (`/proc/<PID>/fd`, kernel sockets with `ss`, and synthetic stress bursts).
3. **Instant Zero-Copy Rollbacks (<2s)**: `automata reset <id>` wipes the tainted sandbox and re-provisions a pristine crisis baseline in under 2 seconds.

---

## 3. Quickstart & CLI Reference

### Installation
Ensure Python 3.12+ is installed on your Linux system.

```bash
# Clone the repository
git clone https://github.com/sweetpinejam/bash-automata.git ~/Documents/bash-automata
cd ~/Documents/bash-automata

# Global launcher symlink
mkdir -p ~/.local/bin
ln -sf ~/Documents/bash-automata/bin/automata ~/.local/bin/automata
```

### Operational Commands

| Command | Description |
| :--- | :--- |
| `automata doctor` | Run diagnostic health check on Python, kernel, cgroups, Docker, and tooling |
| `automata list` | List all available acts, scenarios, and campaign progress |
| `automata status` | Display command center summary dashboard |
| `automata read <id>` | Inspect mission briefing, constraints, and verification contracts |
| `automata start <id>` | Provision runtime sandbox and inject crisis state |
| `automata check <id>` | Run live state verification assertions under synthetic load |
| `automata reset <id>` | Instant rollback to clean baseline state (<2 seconds) |

---

## 4. The 6-Act Campaign (The Incident Room)

* **Act I: The Pipe, the Stream, and the Signal** (POSIX I/O, named pipes, process group signal routing, inotify sentinel loops).
* **Act II: The Daemons, Sockets, and Web Traps** (FastAPI, Nginx, `CLOSE_WAIT` leaks, zero-downtime socket handoffs).
* **Act III: The Cage, the Quota, and the Wire** (cgroups v2 limits, network namespaces, veth routing, memory caps).
* **Act IV: The Automated Fleet** (Self-healing daemons, systemd timers, atomic log rotation).
* **Act V: The Agent on the Leash** (AST static parser with `bashlex`, ShellCheck JSON gate, chroot dry-run diffs).
* **Act VI: The Synthetic Forge** (Autonomous scenario generation, broken-state injection, dynamic verifiers).

---

## 5. Engineering Standards & Git Governance

* **Trunk-Based Development**: `main` is protected. Features branch off `main` and merge via PR.
* **Conventional Commits**: Tag commits with `<type>(<scope>): <summary>`.
  * `feat(act-1): ...`, `guard(ast): ...`, `engine(pty): ...`, `test(verifier): ...`
* **Zero Dependencies for Core Engine**: CLI, SQLite state tracking, and adaptive sandbox runners utilize the Python 3.12 standard library.

---

## License

MIT © 2026 Phitsanupong Phoodet (`sweetpinejam`).
