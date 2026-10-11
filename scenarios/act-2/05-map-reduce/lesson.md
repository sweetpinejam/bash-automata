# Tactical Field Manual: The Parallel Map-Reduce Stream

> **Incident Class**: Premature Barrier Release & Data Dropping in Parallel Workloads  
> **Key Tooling**: PID Array Aggregation (`pids+=("$!")`), Cohort Barrier Wait (`wait "${pids[@]}"`)

---

## 1. The Incident: The "Single-PID Wait" Bug

When orchestrating parallel data pipelines in Bash, developers frequently make this mistake:

```bash
# BUG: Only tracks last PID
for file in data_*.log; do
  process "$file" &
  last_pid=$!
done
wait "$last_pid"  # ONLY waits for the last single job!
aggregate_data    # Reducer runs while jobs 1, 2, 3 are still writing!
```

Because `$!` only stores the PID of the **most recently spawned background job**, waiting on `$!` releases execution as soon as the last file completes. If job 1, 2, or 3 is still writing, downstream reducers read partially written files or miss entire partitions completely.

---

## 2. Architecture: Fan-Out & Barrier Join

```
  ORCHESTRATOR
       │
       ├────► mapper.sh part_1.log (PID 101) ──┐
       ├────► mapper.sh part_2.log (PID 102) ──┼──► [pids=(101 102 103 104)]
       ├────► mapper.sh part_3.log (PID 103) ──┤
       └────► mapper.sh part_4.log (PID 104) ──┘
                          │
                          ▼
             wait "${pids[@]}"  (BARRIER)
             Blocks until ALL 4 PIDs finish
                          │
                          ▼
            python3 reducer.py (Safe Aggregation)
```

---

## 3. The Array Barrier Pattern

1. Initialize array: `pids=()`
2. In the fan-out loop:
   - Spawn job: `command &`
   - Capture PID: `pids+=("$!")`
3. Join barrier:
   - `wait "${pids[@]}"`
   - Bash pauses until every PID in the list terminates.
   - If any job failed with non-zero under `set -e`, `wait` returns the error code, halting execution before dirty data reaches the reducer.
