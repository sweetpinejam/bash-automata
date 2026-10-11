# Code Blueprint: Kernel Advisory File Locking with `flock`

Protect shared file appends from multi-process interleaving using Linux kernel advisory file locks (`flock`):

```bash
# Blueprint Pattern:
OUTPUT_FILE="metrics_dump.tsv"
LOCK_FILE="metrics.lock"

# Open dedicated file descriptor 200 to lock file:
exec 200>"$LOCK_FILE"

for (( i=1; i<=10; i++ )); do
  # Acquire exclusive write lock (blocks until released):
  flock -x 200

  # Critical Section (guaranteed zero concurrent writes):
  echo "START_ROW" >> "$OUTPUT_FILE"
  echo -e "worker=$WORKER_ID\tseq=$i\tdata=payload_$i" >> "$OUTPUT_FILE"
  echo "END_ROW" >> "$OUTPUT_FILE"

  # Release lock:
  flock -u 200
done

# Close descriptor:
exec 200>&-
```

> **Key Rule**: Using a dedicated file descriptor (`exec 200>"$LOCK_FILE"`) instead of locking the target file itself prevents lock metadata corruption and file truncation issues.
