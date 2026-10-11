# Code Blueprint: Kubernetes-Style Graceful Drain with Traps

Prevent transaction corruption during pod evictions and rolling updates using a signal latch:

```bash
# Blueprint Pattern:
COMMIT_LOG="transactions.commit"
DRAIN_LOG="drain.log"
PID_FILE="worker.pid"

draining=false
trap 'draining=true' TERM INT

while IFS= read -r job || [[ -n "$job" ]]; do
  [[ -n "$job" ]] || continue

  # Guard: If drain was signaled, stop consuming new queue tasks:
  if $draining; then
    break
  fi

  # In-flight transaction boundary:
  echo "TX_START: $job" >> "$COMMIT_LOG"
  sleep 0.1
  echo "TX_COMMITTED: $job" >> "$COMMIT_LOG"

  # Check if signal arrived during active processing of this transaction:
  if $draining; then
    break
  fi
done < "$QUEUE_FILE"

# Clean drain completion
echo "DRAIN_COMPLETED" > "$DRAIN_LOG"
rm -f "$PID_FILE"
exit 0
```

> **Key Rule**: When `trap 'draining=true' TERM` executes, Bash does NOT interrupt the atomic lines in the body of the current transaction. Setting a boolean flag allows the in-flight work to complete before breaking the loop cleanly.
