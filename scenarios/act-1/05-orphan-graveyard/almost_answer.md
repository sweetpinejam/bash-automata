# Code Blueprint: Child Process Reaping & Zombie Prevention

When a parent process spawns background jobs (`&`), terminating children remain in state `Z` (defunct / zombie) in the Linux kernel process table until the parent collects their exit codes:

```bash
# Blueprint Pattern:
for (( i=1; i<=TOTAL_TASKS; i++ )); do
  (
    echo "TASK_$i: DONE" >> "$done_file"
    exit 0
  ) &
done

# Reap all active and terminated children:
wait
```

> **Key Rule**: Calling `wait` without arguments pauses until ALL background child processes spawned by the current shell have terminated and reaps their kernel exit entries.
