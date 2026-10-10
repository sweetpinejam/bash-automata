#!/usr/bin/env bash
set -euo pipefail

rm -f final.conf
cat <<'EOF' > template.conf
server {
    listen 8080;
    server_name localhost;
    # Regex with backslashes
    location ~* \.(jpg|jpeg|png)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
EOF

chmod +x compiler.sh
