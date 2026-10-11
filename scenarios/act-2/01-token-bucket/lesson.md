# Tactical Field Manual: The Token Bucket Semaphore

> **Incident Class**: Concurrent Rate Limiting & Semaphore Throttling  
> **Key Tooling**: POSIX Named Pipe (`mkfifo`), Bidirectional File Descriptors (`exec 3<>`), Subshell Replenishment

---

## 1. The Incident: The Unthrottled Thundering Herd

In automated batch processing, scripts frequently launch worker processes in background subshells:

```bash
for item in "${items[@]}"; do
  process_item "$item" &
done
wait
```

If the queue contains 100 items, Bash immediately forks 100 concurrent subshell processes. In microservice environments, this triggers three catastrophic failure modes:
1. **Upstream Rate Limiting (HTTP 429)**: The target API or database rejects sudden burst traffic.
2. **Process Table Starvation**: Forking 100+ processes exhausts kernel PIDs and file descriptors.
3. **Context Switching Thrashing**: CPU thrashing slows total job throughput compared to bounded concurrency.

---

## 2. Architecture: FIFO-Driven Counting Semaphore

```
            ┌──────────────────────────────────────────────┐
            │           Token Bucket FIFO (FD 3)           │
            │           [ ● ]  [ ● ]  [ ● ]  [ ● ]         │
            └───────────────┬──────────────────────────────┘
                            │
               read -u 3    │ (Acquire Token)
               Blocks if    ▼
               empty     [ Worker Slot ]
                            │
                            │ (Runs background job)
                            ▼
               echo >&3     │ (Release Token)
                            ▼
            ┌──────────────────────────────────────────────┐
            │           Tokens Returned to Pool            │
            └──────────────────────────────────────────────┘
```

---

## 3. The Core Mechanics

### Why `exec 3<>"$FIFO"`?
If you open a FIFO for read-only (`< "$FIFO"`), `read` encounters `EOF` the moment the pipe becomes temporarily empty, terminating your loop.
Opening with `3<>` tells the kernel to keep the descriptor open for **both reading and writing**. Because the process itself is a registered writer, the kernel will never signal EOF on empty reads—instead, `read -u 3` cleanly blocks until a token arrives.

### The Lifecycle Pattern
1. Create FIFO: `mkfifo "$FIFO"`
2. Bind descriptor: `exec 3<>"$FIFO"`
3. Seed tokens: Write $N$ newlines `echo >&3`
4. In loop:
   - `read -u 3` (blocks until slot is free)
   - `( work; echo >&3 ) &` (releases slot on completion)
5. Barrier: `wait`
6. Teardown: `exec 3>&-`
