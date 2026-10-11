#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${AUTOMATA_WORKSPACE:-$(pwd)}"

rm -f "$WORKSPACE/final.conf"

if [[ -f "$WORKSPACE/compiler.sh" ]]; then
    chmod +x "$WORKSPACE/compiler.sh"
fi

cat << 'EOF' > "$WORKSPACE/template.conf"
# Global Nginx Configuration Template
server {
    listen {{PORT}};
    server_name {{SERVER_NAME}};

    # Static assets regex pattern
    location ~* \.(jpg|jpeg|png|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Reverse proxy upstream
    location /api/ {
        proxy_pass http://{{UPSTREAM}}/;
    }
}
EOF
# Append final line without trailing newline
printf "    # Telemetry: {{TELEMETRY_STATUS}}" >> "$WORKSPACE/template.conf"

echo "[SETUP COMPLETE] Seeded template.conf in workspace"
