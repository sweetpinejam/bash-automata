# Structural Scaffolding: Consecutive Failure Threshold Latch

To prevent deployment rollbacks caused by single transient network drops or microsecond GC pauses, wrap the probe in an `if/else` block with a reset-on-success failure streak:

---

## Pattern: Consecutive Failure Latch

```bash
FAIL_THRESHOLD=3
consecutive_fails=0

for (( i=1; i<=CYCLES; i++ )); do
    # 'if cmd; then' is exempt from 'set -e' abort on non-zero exit codes:
    if run_probe; then
        # RESET: Streak cleared on any successful probe
        consecutive_fails=0
    else
        # INCREMENT: Record consecutive failure
        consecutive_fails=$(( consecutive_fails + 1 ))

        # LATCH TRIPPED: Abort only when sustained outage threshold is met
        if (( consecutive_fails >= FAIL_THRESHOLD )); then
            echo "CANARY_ABORTED: Threshold reached on cycle $i" >&2
            exit 1
        fi
    fi
    sleep "$INTERVAL"
done

# If all cycles complete without tripping the latch:
echo "CANARY_HEALTHY"
exit 0
```

---

## Verifying Latch Behavior

Test against both simulated modes:
```bash
# Test 1: Transient mode (should exit 0 with CANARY_HEALTHY):
PROBE_MODE=transient bash canary_checker.sh

# Test 2: Outage mode (should exit 1 with CANARY_ABORTED after 3 cycles):
PROBE_MODE=outage bash canary_checker.sh
```
