#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: Automated Configuration Forge
# ==============================================================================
set -euo pipefail

APP_NAME="telemetry-collector"
PORT="9090"

# Unquoted heredoc with escaped \$MAINPID to preserve literal systemd directive
cat <<EOF > service.conf
[Unit]
Description=$APP_NAME
After=network.target

[Service]
Environment=PORT=$PORT
ExecStart=/usr/local/bin/$APP_NAME --port=$PORT
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

# Quoted heredoc (<<'EOF') treats all contents completely literally:
cat <<'EOF' > run.sh
#!/usr/bin/env bash
echo "Executing agent for target: $1"
EOF
chmod +x run.sh

echo "FORGE_COMPLETE"
