#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"
cd "$WORKSPACE"

rm -f probe_attempts.log probe_summary.json mock_service.sh daemon_port.txt service_endpoint.env
if [[ -f daemon.pid ]]; then
    kill "$(cat daemon.pid)" 2>/dev/null || true
    rm -f daemon.pid
fi

if [[ ! -f "$WORKSPACE/health_daemon.py" ]] && [[ -f "$(dirname "$0")/health_daemon.py" ]]; then
    cp "$(dirname "$0")/health_daemon.py" "$WORKSPACE/health_daemon.py"
fi

# Launch health daemon in background (succeeds on attempt 3)
python3 "$WORKSPACE/health_daemon.py" --ready-after 3 --port-file "$WORKSPACE/daemon_port.txt" >/dev/null 2>&1 &
echo $! > "$WORKSPACE/daemon.pid"

# Wait up to 2 seconds for port file to appear
for _ in {1..20}; do
    if [[ -f "$WORKSPACE/daemon_port.txt" ]]; then
        break
    fi
    sleep 0.1
done

if [[ -f "$WORKSPACE/daemon_port.txt" ]]; then
    PORT=$(cat "$WORKSPACE/daemon_port.txt" | tr -d '[:space:]')
    echo "TARGET_URL=\"http://127.0.0.1:$PORT/health\"" > "$WORKSPACE/service_endpoint.env"
fi

if [[ -f "$WORKSPACE/probe.sh" ]]; then
    chmod +x "$WORKSPACE/probe.sh"
fi

echo "[SETUP COMPLETE] Workspace primed for Exponential Backoff drill."
