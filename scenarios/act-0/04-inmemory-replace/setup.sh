#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/events.sanitized" "$WORKSPACE/audit_metrics.json"

if [[ -f "$WORKSPACE/sanitizer.sh" ]]; then
    chmod +x "$WORKSPACE/sanitizer.sh"
fi

# Seed events.raw with prefix, global, suffix, clean lines, and no trailing newline on final line
cat << 'EOF' > "$WORKSPACE/events.raw"
DEBUG: worker daemon thread started
INFO: connection established to db.dev.internal:5432
WARN: missing auth token on request to api.dev.internal
AUTH: token verified client=SECRET_48291_alpha
INFO: telemetry ping delivered
REQUEST: GET https://portal.dev.internal/home?session=fe89123ac
EOF
# Append final line without trailing newline
printf "DEBUG: sweep task completed token=SECRET_9999" >> "$WORKSPACE/events.raw"

echo "[SETUP COMPLETE] Seeded 7 log events in events.raw"
