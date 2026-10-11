# Structural Scaffolding: Dynamic Slot Replenishment with `wait -n`

To prevent CPU worker slots from sitting idle while waiting for stragglers in lockstep batches, replenish capacity dynamically using `wait -n`:

---

## Pattern: Dynamic Worker Pool Clamp

```bash
MAX_WORKERS=3
active=0

while IFS= read -r task || [[ -n "$task" ]]; do
    [[ -n "$task" ]] || continue

    # Dispatch worker to background
    run_worker "$task" &
    active=$(( active + 1 ))

    # When pool reaches capacity, wait for ANY single child to finish:
    if (( active >= MAX_WORKERS )); then
        wait -n
        # Safe assignment arithmetic avoiding (( 0 )) crash under set -e
        active=$(( active - 1 ))
    fi
done < "$QUEUE_FILE"

# Final Barrier: Drain all remaining active workers before terminating
wait
```

---

## Verifying Concurrency & Throughput

Observe that worker slots never sit idle during queue execution:
```bash
# Monitor active worker subshells:
while true; do
    ps aux | grep "[w]orker.py" | wc -l
    sleep 0.05
done
```
The active worker count will remain steadily pegged at 3 until the queue drains.
