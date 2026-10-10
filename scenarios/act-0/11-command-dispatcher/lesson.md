# Tactical Field Manual: The Command Dispatcher (`case ... in ... esac`)

## 1. The Mental Model (Clean Branching in Shell CLIs)
When building CLI tools and service automation controllers, you frequently need to route actions (`start`, `stop`, `restart`, `status`, `--help`).
Chaining 10 `if [[ ... ]] elif [[ ... ]]` statements is verbose, error-prone, and slow.

Bash provides the native **`case`** construct:
```bash
case "$VARIABLE" in
    pattern1)
        # Commands for pattern 1
        ;;
    pattern2|pattern3)
        # Grouped alternate patterns
        ;;
    *)
        # Default catch-all (wildcard)
        ;;
esac
```

---

## 2. Syntax Rules of `case`

1. **Closing Parenthesis `)`**: Each pattern ends with a single `)`.
2. **Double Semicolons `;;`**: Every branch MUST terminate with `;;` (equivalent to `break` in C/Python switch statements).
3. **Pipe `|` for OR**: Combine aliases together cleanly: `-v|--verbose|verbose)`.
4. **Wildcards `*` and Globs**: Patterns support glob wildcards: `*.log)` or `[0-9]*)`.
5. **Catch-All `*)`**: Always place a wildcard at the very end to catch unknown arguments, print usage instructions, and `exit 1`.

---

## 3. Syntax Cheatsheet: Daemon Controller Pattern

```bash
action="${1:-help}"

case "$action" in
    start)
        echo "Starting daemon..."
        ;;
    stop)
        echo "Stopping daemon..."
        ;;
    restart)
        "$0" stop
        "$0" start
        ;;
    -h|--help|help)
        echo "Usage: $0 {start|stop|restart}"
        ;;
    *)
        echo "Error: Unknown action '$action'" >&2
        exit 1
        ;;
esac
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `case word in`)
* Greg's Bash Wiki: [The Case Statement](https://mywiki.wooledge.org/BashGuide/Patterns#The_case_statement)
* GNU Bash Reference Manual: Section 3.2.4.2 (Conditional Constructs)

---

## 5. Mission Objective
Edit `service_ctl.sh` in your sandbox. Implement a full `case ... in ... esac` dispatcher handling `start`, `stop`, `status`, `-h|--help|help`, and a defensive `*)` fallback error handler.
Verify all transitions with `[4] Run State Verification`.
