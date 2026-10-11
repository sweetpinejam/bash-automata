# Code Blueprint: POSIX Daemon Signal Dispatching

Handle Linux signals asynchronously by registering trap handlers before entering the event loop:

```bash
# Blueprint Pattern:
reload_config() {
  source app.conf
  echo "CONFIG_RELOADED: BACKEND=$BACKEND" >> "$log_file"
}

dump_metrics() {
  echo "REQUESTS_HANDLED=$requests_handled BACKEND=$BACKEND" > metrics.dump
}

terminate_daemon() {
  running=false
}

# Attach handlers to POSIX signals:
trap reload_config HUP
trap dump_metrics USR1
trap terminate_daemon TERM INT
```

> **Key Rule**: In Bash loops containing blocking commands, running `sleep 0.1 & wait $!` allows the shell to immediately interrupt the sleep and process incoming signals without lag.
