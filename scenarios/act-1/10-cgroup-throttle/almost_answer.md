# Structural Scaffolding: Constant O(1) Memory Ingestion Streaming

When ingesting large or unbounded feeds under tight memory restrictions (cgroup `memory.max`), accumulating data into shell arrays triggers heap expansion and OOM kills.

---

## Pattern: Constant-Memory Stream Processing

Process lines strictly one at a time and pipe directly from input to output:

```bash
# Direct stream redirection on the loop structure:
while IFS= read -r line || [[ -n "$line" ]]; do
    echo "$PREFIX: $line"
done < "$INPUT_FILE" > "$OUTPUT_FILE"
```

### Key Differences vs Array Accumulation:
1. **$O(1)$ Space Complexity**: Process memory remains constant (~3 MB RSS) whether processing 10 records or 10,000,000 records.
2. **File Descriptor Reuse**: Redirecting once on `done > output` keeps the file descriptor open, avoiding repeated filesystem open/close operations.

---

## Verifying Resident Memory Footprint (RSS)

Profile your process memory during execution:
```bash
# Query live Resident Set Size and Peak High Water Mark:
cat /proc/$PID/status | grep -E "VmRSS|VmHWM"
```
Under the streaming pattern, `VmRSS` will remain strictly flat throughout the entire ingestion run.
