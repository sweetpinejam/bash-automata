# Tactical Field Manual: The Phantom Signal (POSIX Signals & Hot Reloads)

## 1. The Architecture (Zero-Downtime Linux Service Control)
In production systems, restarting a process when configuration updates occur introduces severe penalties:
- Active TCP socket connections are severed.
- In-flight client transactions fail.
- Database connection pools must be re-established from scratch.

To achieve **Zero Downtime**, Linux services utilize **POSIX Signals**:

| Signal | Number | Standard Production Convention | Default Linux Action |
| :--- | :--- | :--- | :--- |
| **`SIGHUP`** | `1` | Hangup: **Hot reload configuration files** without restarting. | Terminate process |
| **`SIGUSR1`** | `10` | User-defined 1: **Dump telemetry / statistics** to disk. | Terminate process |
| **`SIGUSR2`** | `12` | User-defined 2: **Reopen log files** (log rotation). | Terminate process |
| **`SIGTERM`** | `15` | Terminate: **Graceful draining shutdown**. | Terminate process |

---

## 2. The Danger: Untrapped Signals
Notice the rightmost column: **The default OS action for unhandled `SIGHUP` and `SIGUSR1` is to KILL THE PROCESS!**

If your daemon does not explicitly declare signal handlers:
```bash
kill -HUP $PID
```
The kernel will forcefully terminate your daemon immediately!

---

## 3. Implementing Signal Handlers in Bash
Bash allows binding custom functions to specific signals via `trap`:

```bash
reload_config() {
    echo "Reloading configuration..."
    source /etc/app.conf
}

dump_metrics() {
    echo "Dumping telemetry..."
    echo "REQUESTS=$count" > /var/log/stats.dump
}

# Register traps
trap reload_config HUP
trap dump_metrics USR1
trap 'running=false' TERM INT
```

> **Crucial Tip on Event Loops**:
> If your loop calls `sleep 60`, a standard `sleep` process will block signal delivery until the sleep finishes.
> To process signals immediately, sleep in the background and wait on its PID:
> ```bash
> sleep 1 &
> wait $! 2>/dev/null || true
> ```
> `wait` returns immediately when any trapped signal arrives!

---

## 4. Recommended Reading List
* `man 7 signal` (Overview of signals and default actions)
* W. Richard Stevens: Advanced Programming in the UNIX Environment (Chapter 10: Signals)
* NGINX Architecture: Controlling NGINX via Signals

---

## 5. Mission Objective
Edit `proxy.sh` in your sandbox. Bind `reload_config` to `HUP` and `dump_metrics` to `USR1` so that the daemon re-reads `app.conf` and dumps metrics on demand without dropping connections.
Verify with `[4] Run State Verification`.
