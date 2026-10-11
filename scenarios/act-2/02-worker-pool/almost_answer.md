# Code Blueprint: Dynamic Slot Replenishment with `wait -n`

Instead of waiting for all workers in lockstep batches (`wait`), use `wait -n` (Bash 4.3+) to wait for the next single background job to terminate:

```bash
# Blueprint Pattern:
MAX_WORKERS=3
active=0

while IFS= read -r task || [[ -n "$task" ]]; do
  [[ -n "$task" ]] || continue

  python3 worker.py "$task" &
  (( active += 1 ))

  # When pool reaches capacity, wait for ANY single child to finish:
  if (( active >= MAX_WORKERS )); then
    wait -n
    (( active -= 1 ))
  fi
done < "$QUEUE_FILE"

# Drain any remaining active workers:
wait
```

> **Key Rule**: `wait -n` pauses until **any** background job terminates and returns its exit code. Decrementing `(( active -= 1 ))` immediately unlocks the loop to launch the next pending task.
