#!/usr/bin/env bash
# ==============================================================================
# Automated Configuration Forge
# Objective: Generate service.conf and run.sh using safe Heredocs
# ==============================================================================
set -euo pipefail

APP_NAME="telemetry-collector"
PORT="9090"

# BROKEN: In the unquoted heredoc below, $MAINPID is expanded by Bash into
# an empty string because MAINPID is not a shell variable!
cat <<EOF > service.conf
[Unit]
Description=$APP_NAME
After=network.target

[Service]
Environment=PORT=$PORT
ExecStart=/usr/local/bin/$APP_NAME --port=$PORT
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

# BROKEN: The script below also expanded $1 into an empty string!
cat <<EOF > run.sh
#!/usr/bin/env bash
echo "Executing agent for target: $1"
EOF
chmod +x run.sh

echo "FORGE_COMPLETE"
