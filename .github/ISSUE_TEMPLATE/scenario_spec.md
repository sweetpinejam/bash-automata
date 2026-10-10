---
name: "Scenario Specification"
about: "Propose or design a new incident scenario"
title: "[SCENARIO] Act X - <Mission Name>"
labels: ["scenario", "needs-triage"]
---

### 1. Incident Premise
* **Domain**: (e.g., Stream Interop / Process Supervision / Cgroups / AI Guardrails)
* **The Failure**: What is fundamentally broken when the trainee enters the sandbox?

### 2. Constraints & System Stack
* **Runtime**: (Local Sandbox / Ephemeral Docker / MicroVM)
* **Components**: (Bash, Python 3.12, systemd, FastAPI, Redis, etc.)
* **Resource Limits**: CPU, RAM, and PID ceilings.

### 3. Verification Contracts
* **Target State**: What files, sockets, process trees, or HTTP codes must verify?
* **Forbidden Workarounds**: What crude hacks must the verifier fail? (e.g., `kill -9 -1`)

### 4. Automated Chaos / Test Ingestion
* How will the harness flood or test the trainee's patch under active load?
