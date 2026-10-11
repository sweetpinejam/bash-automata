# Structural Scaffolding: Scenario 2.10 (The Graceful Drain Teardown)

> **Objective**: Implement a two-phase graceful drain protocol for queue consumer daemons during container rollouts and evictions, preventing torn database transactions upon receiving `SIGTERM`.

---

### Architectural Pattern: Two-Phase Signal Latching

When an orchestrator (Kubernetes, ECS, Docker) evicts a container, it dispatches `SIGTERM` and grants a grace period (e.g., 30 seconds). To guarantee zero data corruption:
1. **Signal Latch**: The trap handler sets an idempotent boolean flag (`draining=true`).
2. **Pre-Transaction Boundary**: Check `$draining` before dequeuing new tasks. If true, break immediately.
3. **In-Flight Protection**: If `SIGTERM` arrives while processing a transaction, the current unit of work finishes completely.
4. **Post-Transaction Boundary**: Check `$draining` after committing the job, then cleanly exit with code 0 and emit `DRAIN_COMPLETED`.

```
  [Container Orchestrator]
            │
            ├─► Dispatches SIGTERM (Pod Eviction / Rolling Update)
            ▼
   [Worker Signal Trap]
   trap 'draining=true' TERM INT
            │
            ▼
    [Worker Processing Loop]
   ┌────────────────────────────────────────────────────────┐
   │ Check 1: if $draining; then break; fi                  │
   │                                                        │
   │ TX_START: job_id                                       │
   │ [In-flight database commit operation...]               │
   │ (SIGTERM caught here -> marks draining=true)           │
   │ TX_COMMITTED: job_id                                   │
   │                                                        │
   │ Check 2: if $draining; then break; fi                  │
   └───────────────────────────┬────────────────────────────┘
                               │
                               ▼
               echo "DRAIN_COMPLETED" > drain.log
               rm -f worker.pid
               exit 0 (Graceful Teardown Acknowledged)
```

---

### Structural Skeleton

```bash
# 1. State Latch & Trap Registration
draining=false

handle_signal() {
    # Idempotent state flag latch
    draining=true
}

# Trap termination signals
trap handle_signal TERM INT

# Record daemon PID
echo "$$" > "$PID_FILE"

# 2. Main Consumer Loop with Safe Transaction Boundaries
while IFS= read -r job || [[ -n "$job" ]]; do
    [[ -n "$job" ]] || continue

    # Boundary Guard 1: Do not pick up new work if drain is active
    if [[ "$draining" == true ]]; then
        break
    fi

    # In-Flight Transaction (Must remain uninterrupted)
    echo "TX_START: $job" >> "$COMMIT_LOG"
    sleep 0.1
    echo "TX_COMMITTED: $job" >> "$COMMIT_LOG"

    # Boundary Guard 2: Exit loop immediately after finishing in-flight job
    if [[ "$draining" == true ]]; then
        break
    fi
done < "$QUEUE_FILE"

# 3. Teardown & Acknowledgement
if [[ "$draining" == true ]]; then
    echo "DRAIN_COMPLETED" > "$DRAIN_LOG"
fi

rm -f "$PID_FILE"
exit 0
```

---

### Key Operational Rules

1. **Avoid Heavy Logic Inside Traps**:
   Do not perform multi-step database cleanups or network calls directly inside the `trap` handler. Asynchronous execution in trap contexts can produce re-entrancy issues. Keep the trap handler minimal (setting a flag).

2. **Strict In-Flight Commitment**:
   Never abort an in-flight transaction mid-operation. Complete the database commit and state persistence before acknowledging drain completion.

3. **Orchestrator Grace Periods**:
   The execution duration of an in-flight transaction must never exceed the container orchestrator's `terminationGracePeriodSeconds` (default 30s in Kubernetes).
