#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/threats.csv"

if [[ -f "$WORKSPACE/classifier.sh" ]]; then
    chmod +x "$WORKSPACE/classifier.sh"
fi

cat << 'EOF' > "$WORKSPACE/firewall.log"
ALERT ts=1700000001 ip=192.168.1.100 port=443 reason=SQL_INJECTION
NOTICE ts=1700000002 ip=10.0.0.5 port=80 msg=connection_closed
ALERT ts=1700000003 ip=45.33.32.156 port=22 reason=BRUTE_FORCE_AUTH
INFO ts=1700000004 ip=127.0.0.1 port=5432 msg=heartbeat_ok
ALERT ts=1700000005 ip=198.51.100.22 port=8080 reason=REMOTE_CODE_EXEC
ALERT ts=1700000006 ip=10.2.1.80 port=3306 reason=UNAUTHORIZED_ACCESS
ALERT ts=1700000007 ip=203.0.113.88 port=80 reason=PORT_SCAN
WARN ts=1700000008 ip=10.0.0.1 port=443 msg=tls_cert_reloaded
EOF

echo "[SETUP COMPLETE] Seeded 8 firewall events in firewall.log"
