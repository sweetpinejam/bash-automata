#!/usr/bin/env bash
# ==============================================================================
# DRILL 0.20: THE HEREDOC TEMPLATE FORGE (<<EOF, <<'EOF', <<-EOF)
# ==============================================================================
# Multi-format configuration forge generating systemd units, proxy configs,
# and shell scripts with precise interpolation and quoting control.
#
# MISSION:
# 1. Enable defensive execution ('set -euo pipefail').
# 2. Accept parameters:
#    - APP_NAME="${1:-${APP_NAME:-telemetry-collector}}"
#    - PORT="${2:-${PORT:-9090}}"
# 3. Forge 'service.conf' using unquoted heredoc (<<EOF):
#    - Interpolate $APP_NAME and $PORT
#    - ESCAPE \$MAINPID so it remains a literal token for systemd!
# 4. Forge 'proxy.conf' using tab-stripped heredoc (<<-EOF):
#    - Must be indented with leading hard TAB characters in source code
#    - Interpolate $PORT into proxy_pass directive
# 5. Forge 'run.sh' using quoted heredoc (<<'EOF'):
#    - Preserve literal $1 and $@ without premature expansion
#    - Mark executable via 'chmod +x run.sh'
# 6. Emit 'forge_manifest.json' cataloging generated artifacts and byte sizes.
# ==============================================================================

set -euo pipefail

APP_NAME="${1:-${APP_NAME:-telemetry-collector}}"
PORT="${2:-${PORT:-9090}}"

# ------------------------------------------------------------------------------
# Artifact 1: Systemd Unit Configuration (Unquoted Heredoc)
# ------------------------------------------------------------------------------
# BROKEN: $MAINPID is unescaped, causing Bash to expand it to an empty string!
cat <<EOF > service.conf
[Unit]
Description=$APP_NAME Service
After=network.target

[Service]
Type=simple
Environment=PORT=$PORT
ExecStart=/usr/local/bin/$APP_NAME --port=$PORT
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------------------------
# Artifact 2: NGINX Proxy Configuration (Tab-Stripped Heredoc <<-EOF)
# ------------------------------------------------------------------------------
forge_proxy() {
	# TODO: Generate proxy.conf using 'cat <<-EOF > proxy.conf'
	# Indent lines using hard TAB characters so leading tabs are stripped in output.
	echo "proxy config placeholder" > proxy.conf
}
forge_proxy

# ------------------------------------------------------------------------------
# Artifact 3: Shell Runner Script (Quoted Literal Heredoc <<'EOF')
# ------------------------------------------------------------------------------
# BROKEN: Delimiter is unquoted, so $1 and $@ expand to empty strings!
cat <<EOF > run.sh
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
