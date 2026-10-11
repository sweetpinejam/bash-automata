# Tactical Field Manual: The Graceful Drain Teardown

> **Incident Class**: Rolling Update Evictions, In-Flight Corruption & Signal Latches  
> **Key Tooling**: `trap 'draining=true' TERM INT`, State Latching, Transaction Boundary Guards

---

## 1. The Incident: Container Rolling Updates & Truncated State

In Kubernetes, AWS ECS, or Docker Swarm, updating a deployment causes the control plane to send `SIGTERM` to existing pods:
1. Orchestrator sends `SIGTERM` to the container's PID 1.
2. The orchestrator grants a **grace period** (default 30 seconds) for the container to terminate cleanly.
3. If the process exits code 0 within the grace period, the pod is removed cleanly.
4. If the process ignores or mishandles the signal, the orchestrator follows up with `SIGKILL`.

If your queue consumer does NOT trap `SIGTERM`:
- The default OS behavior immediately kills the process in the middle of executing a database write.
- Half-written transaction records corrupt database integrity.

---

## 2. Architecture: Two-Phase Graceful Drain

```
  QUEUE WORKER LOOP
  ┌────────────────────────────────────────────────────────┐
  │ 1. Check $draining ──► If true: EXIT LOOP IMMEDIATELY  │
  │                                                        │
  │ 2. TX_START                                            │
  │ 3. [Active database commit processing...]              │
  │    (SIGTERM arrives here! Sets: draining=true)         │
  │ 4. TX_COMMITTED (Current job finishes completely!)     │
  │                                                        │
  │ 5. Check $draining ──► Now true: BREAK LOOP            │
  └───────────────────────────┬────────────────────────────┘
                              │
                              ▼
            echo "DRAIN_COMPLETED" > drain.log
            exit 0 (Clean Kubernetes Pod Teardown)
```

---

## 3. The Signal Latch Pattern

Instead of performing heavy teardown directly inside the signal trap handler:
1. The trap handler does one thing: sets a flag `draining=true`.
2. The main loop checks `if $draining; then break; fi` at well-defined **safe transaction boundaries**.
3. In-flight tasks complete atomically without interruption, while new queue jobs are safely left for replacement pods.
