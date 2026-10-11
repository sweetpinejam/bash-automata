# Structural Scaffolding: Cascading Process Tree Teardown

When tearing down a background workload that forks its own descendant tasks, signaling only the top-level parent leaves grandchildren orphaned in the background.

---

## Pattern A: PPID Matching (`pkill -P`)

Match and terminate all child processes that declare the target as their Parent PID (PPID) before terminating the target:

```bash
# 1. Terminate all direct children of the target PID:
pkill -P "$target_pid" 2>/dev/null || true

# 2. Terminate the top-level process:
kill -TERM "$target_pid" 2>/dev/null || true

# 3. Collect exit code to prevent zombie entries:
wait "$target_pid" 2>/dev/null || true
```

---

## Pattern B: Process Group Broadcasting (`kill -- -$PGID`)

If the target was started as its own process group leader:

```bash
# Query the Process Group ID:
pgid=$(ps -o pgid= -p "$target_pid" | tr -d ' ')

# Broadcast to all processes in the group (negative PGID):
kill -TERM -- "-$pgid" 2>/dev/null || true

wait "$target_pid" 2>/dev/null || true
```

---

## Verifying Zero Rogue Processes

Inspect your process table after teardown to verify no grandchildren remain:
```bash
# Check if any recorded grandchild PIDs survived:
while read -r pid; do
    if kill -0 "$pid" 2>/dev/null; then
        echo "LEAK: Grandchild $pid is still alive!"
    fi
done < grandchildren.pids
```
