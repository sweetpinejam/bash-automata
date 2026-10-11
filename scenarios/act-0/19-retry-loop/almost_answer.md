# Code Blueprint: Exponential Backoff Retry Loop

Implement resilient network polling using a structured `while (( ... ))` loop with escalating sleep intervals:

```bash
# Blueprint Pattern:
attempt=1
max_attempts=4
delay_ms=20

while (( attempt <= max_attempts )); do
  if ./mock_service.sh; then
    echo "SERVICE_READY"
    exit 0
  fi
  sleep "0.0$delay_ms"
  (( attempt += 1 ))
  (( delay_ms *= 2 ))
done

echo "PROBE_TIMEOUT" >&2
exit 1
```

> **Key Rule**: Test the command condition directly inside `if ./command; then`. Arithmetic operators like `(( delay_ms *= 2 ))` enable fast integer progression without external tools.
