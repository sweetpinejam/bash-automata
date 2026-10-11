#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.20 (The Heredoc Template Forge)
# ==============================================================================
# Multi-format configuration forge with precise quoting, interpolation, and tabs.
# ==============================================================================

set -euo pipefail

APP_NAME="${1:-${APP_NAME:-telemetry-collector}}"
PORT="${2:-${PORT:-9090}}"

# ------------------------------------------------------------------------------
# Artifact 1: Systemd Unit Configuration (Unquoted Heredoc)
# ------------------------------------------------------------------------------
# Unquoted heredoc allows $APP_NAME and $PORT to interpolate, while \$MAINPID
# is escaped with backslash to remain a literal systemd variable.
cat <<EOF > service.conf
[Unit]
Description=$APP_NAME Service
After=network.target

[Service]
Type=simple
Environment=PORT=$PORT
ExecStart=/usr/local/bin/$APP_NAME --port=$PORT
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------------------------
# Artifact 2: NGINX Proxy Configuration (Tab-Stripped Heredoc <<-EOF)
# ------------------------------------------------------------------------------
# The <<- syntax strips leading hard TAB characters from each line and closing EOF.
forge_proxy() {
	cat <<-EOF > proxy.conf
	server {
		listen 80;
		server_name localhost;

		location / {
			proxy_pass http://127.0.0.1:$PORT;
			proxy_set_header Host \$host;
		}
	}
	EOF
}
forge_proxy

# ------------------------------------------------------------------------------
# Artifact 3: Shell Runner Script (Quoted Literal Heredoc <<'EOF')
# ------------------------------------------------------------------------------
# Quoting the delimiter token (<<'EOF') prevents all parameter expansion.
cat <<'EOF' > run.sh
#!/usr/bin/env bash
set -euo pipefail
echo "Executing agent for target: $1"
echo "All arguments: $@"
EOF
chmod +x run.sh

# ------------------------------------------------------------------------------
# Artifact 4: Manifest
# ------------------------------------------------------------------------------
cat <<EOF > forge_manifest.json
{
  "status": "SUCCESS",
  "app_name": "$APP_NAME",
  "port": $PORT,
  "artifacts": [
    {"name": "service.conf", "size": $(wc -c < service.conf | tr -d ' ')},
    {"name": "proxy.conf", "size": $(wc -c < proxy.conf | tr -d ' ')},
    {"name": "run.sh", "size": $(wc -c < run.sh | tr -d ' ')}
  ]
}
EOF

echo "FORGE_COMPLETE: artifacts=3, app=$APP_NAME, port=$PORT, status=SUCCESS"
