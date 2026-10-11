# Tactical Blueprint: Truncated Exponential Backoff Loop

To implement resilient polling against an initializing network service or flapping upstream:

---

## 1. Pure Arithmetic Backoff Loop
Use arithmetic expansion assignment `delay=$(( delay * 2 ))` to avoid the `(( 0 ))` false return code trap under `set -e`:

```bash
attempt=1
max_attempts="${MAX_ATTEMPTS:-5}"
delay=1
max_delay=8

while (( attempt <= max_attempts )); do
    # Probe using curl:
    # -s: Silent
    # -f: Fail on HTTP 4xx/5xx (returns exit code 22)
    # -m: Maximum execution timeout in seconds
    if response=$(curl -s -f -m 2 "$TARGET_URL"); then
        echo "PROBE_SUCCESS: attempts=$attempt, target=$TARGET_URL, status=READY"
        exit 0
    fi

    # Do not sleep after the final attempt
    if (( attempt == max_attempts )); then
        break
    fi

    sleep "$delay"
    attempt=$(( attempt + 1 ))
    delay=$(( delay * 2 ))
    if (( delay > max_delay )); then
        delay="$max_delay"
    fi
done

echo "PROBE_TIMEOUT: Exhausted $max_attempts attempts against $TARGET_URL" >&2
exit 1
```

---

## 2. Emitting JSON Summary Manifest
When embedding the HTTP response payload (which is already JSON) into `probe_summary.json`:

```bash
cat <<EOF > "./probe_summary.json"
{
  "status": "SERVICE_READY",
  "target_url": "$TARGET_URL",
  "total_attempts": $attempt,
  "response": ${response:-"{}"},
  "completed_at": $(date +%s)
}
EOF
```

---

## 3. Key Rules
- **Break before sleeping on the last attempt**: Avoid wasting time sleeping when the budget is already exhausted.
- **Log each attempt**: Append to `probe_attempts.log` with status, exit code, and backoff delay.
- **Always cap delay**: Use `max_delay` to prevent unbounded exponential sleep durations.
- **Assignment arithmetic**: Prefer `delay=$(( delay * 2 ))` over `(( delay *= 2 ))` to avoid `set -e` failure when `delay=0`.
