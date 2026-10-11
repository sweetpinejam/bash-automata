# Code Blueprint: Structured Dispatch with `case ... in ... esac`

Use `case` to implement a clean multi-branch command dispatcher:

```bash
# Blueprint Pattern:
case "$action" in
  start)
    echo "$$" > "$pid_file"
    echo "SERVICE_STARTED"
    ;;
  stop)
    rm -f "$pid_file"
    echo "SERVICE_STOPPED"
    ;;
  status)
    if [[ -f "$pid_file" ]]; then
      echo "STATUS_RUNNING"
    else
      echo "STATUS_STOPPED"
    fi
    ;;
  -h|--help|help)
    echo "USAGE: service_ctl.sh {start|stop|status|-h|--help}"
    exit 0
    ;;
  *)
    echo "ERROR: Unknown action '$action'" >&2
    exit 1
    ;;
esac
```

> **Key Rule**: Terminate each case branch with `;;`. Use `|` to match multiple aliases in a single clause.
