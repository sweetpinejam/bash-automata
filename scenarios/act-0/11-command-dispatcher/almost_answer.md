# Code Blueprint & Almost-Answer: The Command Dispatcher

If you need structural routing templates for `service_ctl.sh`:

### 1. The `case` Routing Skeleton
```bash
case "$ACTION" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        [[ -f "$PID_FILE" ]] && stop_service
        start_service
        ;;
    status)
        check_status
        ;;
    -h|--help|help)
        echo "Usage: $0 {start|stop|restart|status|help}"
        exit 0
        ;;
    *)
        echo "Error: Unknown action '$ACTION'" >&2
        exit 1
        ;;
esac
```

### 2. PID Checking via `kill -0`
```bash
if [[ -f "$PID_FILE" ]]; then
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo "STATUS: RUNNING (pid=$pid)"
        exit 0
    else
        echo "STATUS: STALE_PID (pid=$pid)"
        exit 2
    fi
else
    echo "STATUS: STOPPED"
    exit 3
fi
```
