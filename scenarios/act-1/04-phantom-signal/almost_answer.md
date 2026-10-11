# Tactical Blueprint: Signal Handling & Zero-Downtime Reloads

To handle asynchronous UNIX signals without crashing or delaying execution:

---

## 1. Registering Custom Handlers via `trap`

```bash
reload_config() {
    source "$CONF_FILE"
    echo "CONFIG_RELOADED: BACKEND=$BACKEND" >> "$LOG_FILE"
}

dump_metrics() {
    echo "REQUESTS_HANDLED=$requests_handled BACKEND=$BACKEND" > "$METRICS_FILE"
}

terminate_daemon() {
    running=false
    rm -f "$PID_FILE"
}

# Bind handlers to signals:
trap reload_config HUP
trap dump_metrics USR1
trap terminate_daemon TERM INT EXIT
```

---

## 2. Low-Latency Event Loop
Never use foreground `sleep 30` in an event loop, because foreground commands defer signal processing until the sleep expires. Use background sleep + wait:

```bash
while $running; do
    (( requests_handled += 1 ))

    # Interruptible sleep allows signals to fire immediately:
    sleep 0.1 &
    wait $! 2>/dev/null || true
done
```
