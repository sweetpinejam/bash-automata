# Code Blueprint: Consecutive Failure Threshold Latch

Avoid deployment flapping caused by single transient errors by tracking consecutive failures in Bash:

```bash
# Blueprint Pattern:
FAIL_THRESHOLD=3
consecutive_fails=0

for (( i=1; i<=CYCLES; i++ )); do
  if python3 health_endpoint.py; then
    # Reset failure streak on any successful probe:
    consecutive_fails=0
  else
    # Increment failure streak:
    (( consecutive_fails += 1 ))
    if (( consecutive_fails >= FAIL_THRESHOLD )); then
      echo "CANARY_ABORTED: Service failed $consecutive_fails consecutive probes" >&2
      exit 1
    fi
  fi
  sleep 0.01
done

echo "CANARY_HEALTHY"
exit 0
```

> **Key Rule**: Resetting `consecutive_fails=0` on each success converts a naive binary error check into a resilient sliding window, absorbing transient blips while still catching true sustained outages.
