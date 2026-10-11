# Tactical Field Manual: The Flaking Healthcheck Latch

> **Incident Class**: Health Probe Flapping & False Positive Rollback  
> **Key Tooling**: Consecutive Failure Counters, Sliding Windows, Resilient Exit Control

---

## 1. The Incident: False-Positive Canary Failures

In continuous delivery (CD) pipelines and Kubernetes liveness/readiness probes, automated canaries test new release candidates before directing 100% of user traffic:

```bash
# NAIVE PROBE: Flaps on first blip
for probe in {1..10}; do
  if ! check_health; then
    trigger_rollback  # FAILS on 1 dropped packet!
  fi
done
```

In distributed systems, microservices frequently encounter **transient blips**:
- A 10ms garbage collection pause
- An upstream DNS cache renewal
- A transient TCP socket reset

A naive probe that aborts on a single blip will fail 80–90% of valid canary deployments.

---

## 2. Architecture: Threshold Latch Pattern

```
  Cycle:        1      2      3      4      5      6      7      8      9      10
  Status:      [OK]   [OK]  [FAIL]  [OK]   [OK]   [OK]  [FAIL]  [OK]   [OK]   [OK]
  Naive:                     └──► ROLLS BACK IMMEDIATELY! (False positive)

  Latch Streak:  0      0      1      0      0      0      1      0      0      0
  (Limit = 3)                 │      │                     │      │
                             OK     RESET                 OK     RESET
                             └──► REMAINS HEALTHY! Deploy succeeds.
```

---

## 3. The Pure Bash Latch Pattern

1. Initialize `consecutive_fails=0`.
2. On every loop iteration:
   - If test passes: `consecutive_fails=0`.
   - If test fails: `(( consecutive_fails += 1 ))`.
   - Check threshold: `if (( consecutive_fails >= FAIL_THRESHOLD )); then abort; fi`.
3. If loop finishes all cycles without hitting the threshold, declare release `CANARY_HEALTHY`.
