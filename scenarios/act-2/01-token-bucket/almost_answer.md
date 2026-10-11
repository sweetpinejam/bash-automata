# Structural Scaffolding: Pure POSIX Concurrency Limiter (FIFO Token Bucket)

To throttle background task dispatching without external tools (`xargs -P` or GNU `parallel`), implement a counting semaphore using a POSIX named pipe and file descriptor.

---

## Pattern: Bidirectional FIFO Semaphore

```bash
CONCURRENCY=4
FIFO="/tmp/sem_$$.fifo"
mkfifo "$FIFO"

# 1. Open FIFO bidirectional to prevent EOF termination on empty reads:
exec 3<>"$FIFO"
# 2. Immediately unlink pathname so no dangling file remains on disk:
rm -f "$FIFO"

# Guarantee descriptor cleanup on script exit:
MAIN_PID=$$
trap 'if [[ "$BASHPID" == "$MAIN_PID" ]]; then exec 3>&- 2>/dev/null || true; fi' EXIT

# 3. Pre-seed the bucket with N tokens:
for (( i=0; i<CONCURRENCY; i++ )); do
    echo >&3
done

# 4. Dispatch loop:
while IFS= read -r item || [[ -n "$item" ]]; do
    [[ -n "$item" ]] || continue

    # ACQUIRE: blocks if all N tokens are in use
    read -u 3

    # Launch worker in background; release token on completion
    (
        run_worker "$item" || true
        echo >&3   # RELEASE: returns token to FD 3
    ) &
done < "$QUEUE_FILE"

# 5. Barrier: Wait for all background subshells to complete
wait

# 6. Teardown
exec 3>&-
```

---

## Verifying Concurrency Bounds

Inspect active worker subshells during execution:
```bash
# Monitor active worker subshells:
watch -n 0.1 'ps aux | grep "[m]ock_api" | wc -l'
```
The active count should never exceed 4 at any moment.
