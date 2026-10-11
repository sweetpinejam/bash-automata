# Tactical Field Manual: The Cascading Timeout Shield

> **Incident Class**: Microservice Socket Hangs, Cascading Exhaustion & Container Portability  
> **Key Tooling**: Parallel Timer Subshells, PID-Targeted Signals, Zero-Dependency Timeouts

---

## 1. The Incident: The Missing `timeout` Binary

In minimal container images (Alpine Linux, distroless, scratch-based CI runners), common GNU coreutils packages are often omitted:
```bash
timeout 5 curl http://internal-service  # FAILS: timeout: not found!
```
When downstream scripts omit timeout handling, network drops or deadlocked database locks cause worker threads to block indefinitely. Within minutes:
1. HTTP connection pools saturate.
2. Kernel file descriptors are exhausted.
3. The entire API gateway halts.

---

## 2. Architecture: Pure Bash Timeout Circuit

```
  CALLER FUNCTION
       │
       ├────► [Command Subshell] (PID 101) ────────► Runs: python3 upstream_rpc.py
       │
       └────► [Watchdog Timer]   (PID 102) ────────► Runs: sleep 1.0
                                                            │
  If command finishes first:                                ▼ (After 1.0s)
  kill $timer_pid (Cancels sleep)             kill -TERM 101 (Interrupts command)
  Returns: 0                                  Returns: 124 (TIMEOUT)
```

---

## 3. Best Practices for Timeout Subshells

1. **Escalating Termination**: First send `SIGTERM`. If the process is caught in an un-interruptible system call or Python GIL freeze, follow up with `SIGKILL` (`kill -9`).
2. **Reaping the Timer**: If the command finishes within the allocated window, **always kill the timer process** (`kill "$timer_pid"`), otherwise background `sleep` processes will linger until their timeout naturally expires.
3. **Exit Code Conventions**: Standard POSIX convention for timeout commands is exit status `124`.
