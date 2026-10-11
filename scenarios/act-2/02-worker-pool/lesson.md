# Tactical Field Manual: The Runaway Worker Pool & `wait -n`

> **Incident Class**: Batch Worker Starvation & Concurrency Pipelining  
> **Key Tooling**: `wait -n`, Subshell PID tracking, Dynamic slot recycling

---

## 1. The Incident: Lockstep Stalls in Queue Workers

When processing a queue with bounded concurrency (e.g. $N=3$ workers), a common anti-pattern is lockstep batching:

```bash
# ANTI-PATTERN: Lockstep Batching
for task in "${tasks[@]}"; do
  run_worker "$task" &
  (( active++ ))
  if (( active >= 3 )); then
    wait          # STALLS! Waits for all 3 to finish
    active=0
  fi
done
```

If one job takes 100ms and the other two take 10ms:
1. Fast workers finish in 10ms.
2. The remaining 2 worker slots **sit completely idle for 90ms** waiting for the slowest job.
3. Over hundreds of jobs, this wastes up to 70% of potential CPU concurrency!

---

## 2. Dynamic Pipelining: Architecture

```
  Lockstep Batching (Naive 'wait'):
  Slot 1: [════════════ Slow Job ════════════]
  Slot 2: [== Fast ==] (IDLE..................) ──► WAITS FOR SLOW JOB
  Slot 3: [== Fast ==] (IDLE..................)

  Dynamic Pipelining ('wait -n'):
  Slot 1: [════════════ Slow Job ════════════]
  Slot 2: [== Fast ==][== Fast ==][== Fast ==] ──► IMMEDIATELY REFILLED
  Slot 3: [== Fast ==][== Fast ==][== Fast ==]
```

---

## 3. The `wait -n` Primitive

Introduced in Bash 4.3, `wait -n`:
- Waits for **any single background job** from the current shell to exit.
- Returns the exit code of that specific child process.
- By decrementing your active counter `(( active -= 1 ))` after `wait -n`, your loop immediately moves forward to read the next item and fill the vacant slot.
