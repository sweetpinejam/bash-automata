#!/usr/bin/env bash
set -euo pipefail

rm -f /tmp/mock_service_call_count.tmp
cat <<'EOF' > mock_service.sh
#!/usr/bin/env bash
COUNTER_FILE="/tmp/mock_service_call_count.tmp"
count=0
if [[ -f "$COUNTER_FILE" ]]; then
  count=$(cat "$COUNTER_FILE")
fi
(( count += 1 ))
echo "$count" > "$COUNTER_FILE"

# Succeeds on the 3rd attempt
if (( count >= 3 )); then
  exit 0
else
  exit 1
fi
EOF

chmod +x mock_service.sh
chmod +x probe.sh
