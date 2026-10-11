# Code Blueprint: Selective & Quoted Heredocs

Control variable expansion inside heredocs:

```bash
# Blueprint Pattern:
# 1. Selective expansion (delimiter unquoted, escape target literals with backslash):
cat <<EOF > service.conf
[Unit]
Description=$APP_NAME

[Service]
Environment=PORT=$PORT
ExecStart=/usr/local/bin/$APP_NAME --port=$PORT
ExecReload=/bin/kill -HUP \$MAINPID
EOF

# 2. Complete literal preservation (quote the EOF delimiter: <<'EOF'):
cat <<'EOF' > run.sh
#!/usr/bin/env bash
echo "Executing agent for target: $1"
EOF
chmod +x run.sh
```

> **Key Rule**:
> - If you want NO expansions inside the heredoc (like generating another bash script), quote the delimiter: `<<'EOF'`.
> - If you want some variables expanded and others kept literal (like systemd's `$MAINPID`), leave `<<EOF` unquoted and escape the literal ones: `\$MAINPID`.
