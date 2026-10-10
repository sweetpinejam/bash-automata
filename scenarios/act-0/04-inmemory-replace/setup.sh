#!/usr/bin/env bash
set -euo pipefail

rm -f events.sanitized
cat <<'EOF' > events.raw
host=node-1;service=payment;url=http://api.dev.internal/pay;secret=SECRET_999123
host=node-2;service=auth;url=http://auth.dev.internal/login;secret=SECRET_444555
host=node-3;service=billing;url=http://billing.dev.internal/invoice;secret=SECRET_777888
EOF

chmod +x sanitizer.sh
