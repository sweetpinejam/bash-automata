# Code Blueprint: Parallel Subshell PID Tracking & Barrier Wait

Launch multiple independent tasks concurrently and establish a deterministic barrier wait using Bash arrays:

```bash
# Blueprint Pattern:
map_pids=()

for part in part_*.log; do
  [[ -f "$part" ]] || continue

  # Spawn task in background subshell:
  bash mapper.sh "$part" &

  # Capture PID of just-spawned background subshell:
  map_pids+=("$!")
done

# Barrier: Wait for ALL mapped subshells to finish:
wait "${map_pids[@]}"

# Run aggregation step only after all outputs are completely flushed:
python3 reducer.py
```

> **Key Rule**: Storing `$!` into an array (`pids+=("$!")`) and calling `wait "${pids[@]}"` ensures the script waits for the entire cohort of background jobs before proceeding to the reduction step.
