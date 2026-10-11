# Code Blueprint & Almost-Answer: The Stream Contract

If you need structural redirection templates for `triage.sh`:

### 1. Dual Stream Redirection
```bash
if (( TEE_ERRORS == 1 )); then
    simulate_noisy_probe > "$STDOUT_LOG" 2> >(tee "$STDERR_LOG" >&2)
    sleep 0.1
else
    simulate_noisy_probe > "$STDOUT_LOG" 2> "$STDERR_LOG"
fi
```

### 2. Stream Metrics via `wc`
```bash
PAYLOAD_LINES=$(wc -l < "$STDOUT_LOG")
PAYLOAD_BYTES=$(wc -c < "$STDOUT_LOG")
ERROR_LINES=$(wc -l < "$STDERR_LOG")
ERROR_BYTES=$(wc -c < "$STDERR_LOG")
```

### 3. Emitting JSON Metrics
```bash
cat <<EOF > "stream_triage_report.json"
{
  "status": "TRIAGED",
  "payload_lines": $PAYLOAD_LINES,
  "payload_bytes": $PAYLOAD_BYTES,
  "error_lines": $ERROR_LINES,
  "error_bytes": $ERROR_BYTES,
  "cross_contamination": false
}
EOF
```
