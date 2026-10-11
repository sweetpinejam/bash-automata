# Code Blueprint: Pure POSIX Concurrency Limiter (FIFO Token Bucket)

Implement a counting semaphore in pure Bash using a named pipe and file descriptor:

```bash
# Blueprint Pattern:
CONCURRENCY=4
FIFO="/tmp/sem_$$.fifo"
mkfifo "$FIFO"
# Open FIFO for read & write on FD 3 to avoid EOF closing:
exec 3<>"$FIFO"
rm -f "$FIFO"

# Pre-populate token bucket with exactly N tokens:
for (( i=0; i<CONCURRENCY; i++ )); do
  echo >&3
done

while IFS= read -r item || [[ -n "$item" ]]; do
  [[ -n "$item" ]] || continue

  # Acquire token (blocks if all 4 slots are occupied):
  read -u 3

  # Run worker in background; replenish token upon exit:
  (
    python3 mock_api.py "$item"
    echo >&3  # Release token back to bucket
  ) &
done < "$QUEUE_FILE"

# Wait for all background workers to finish:
wait
# Close FD 3:
exec 3>&-
```

> **Key Rule**: Opening the FIFO with `exec 3<>"$FIFO"` holds it open for both reading and writing, preventing `read -u 3` from hitting premature EOF when empty.
