#!/usr/bin/env bash
set -euo pipefail

rm -f threats.csv
cat <<'EOF' > firewall.log
ALERT ip=192.168.1.50 port=443 reason=SYN_FLOOD
INFO ip=10.0.0.12 port=80 reason=NORMAL_TRAFFIC
ALERT ip=172.16.0.99 port=22 reason=SSH_BRUTEFORCE
DEBUG ip=127.0.0.1 port=8080 reason=HEALTHCHECK
ALERT ip=203.0.113.5 port=8080 reason=SQL_INJECTION
EOF

chmod +x classifier.sh
