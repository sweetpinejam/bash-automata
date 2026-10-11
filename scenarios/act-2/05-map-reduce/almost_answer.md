# Structural Scaffolding: Parallel Subshell PID Tracking & Barrier Wait

To prevent downstream reducers from running against partially written intermediate files, track all spawned background PIDs in an array and establish a synchronization barrier:

---

## Pattern: Fork-Join Barrier Synchronization

```bash
# 1. Initialize array to capture the worker cohort:
worker_pids=()

# 2. Fan-out / Fork phase:
for partition in data_*.log; do
    [[ -f "$partition" ]] || continue

    # Spawn mapper in background subshell:
    run_mapper "$partition" &

    # Capture the PID of the just-forked background process:
    worker_pids+=("$!")
done

# 3. Join / Barrier phase:
# Blocks until EVERY background worker in the cohort has terminated:
wait "${worker_pids[@]}"

# 4. Reduction phase:
# Guaranteed that all partition intermediate outputs are completely flushed to disk:
run_reducer
```

---

## Verifying Barrier Synchronization

Inspect the intermediate outputs before reduction:
```bash
# Confirm all expected summary partitions exist:
ls -lh summary_part_*.tsv
```
Every partition file must be present and fully written before the reducer executes.
