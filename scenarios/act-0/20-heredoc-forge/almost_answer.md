# Tactical Blueprint: Heredoc Modalities (`<<EOF`, `<<'EOF'`, `<<-EOF`)

To generate systemd services, indented server blocks, and secondary shell scripts without corrupting syntax:

---

## 1. Modality 1: Unquoted Delimiter with Escaped Tokens (`<<EOF`)
Use for templated configurations where variables expand, but escape any literal tokens that start with `$`:

```bash
cat <<EOF > service.conf
[Unit]
Description=$APP_NAME Service

[Service]
ExecStart=/usr/local/bin/$APP_NAME --port=$PORT
ExecReload=/bin/kill -HUP \$MAINPID
EOF
```

---

## 2. Modality 2: Indentation Stripping via Hard Tabs (`<<-EOF`)
When declaring a heredoc inside an indented function, use `<<-EOF` and indent content using **hard TAB characters** (`\t`):

```bash
forge_proxy() {
	cat <<-EOF > proxy.conf
	server {
		listen 80;
		location / {
			proxy_pass http://127.0.0.1:$PORT;
		}
	}
	EOF
}
```

---

## 3. Modality 3: Literal Quoted Delimiter (`<<'EOF'`)
When generating secondary shell scripts, quote the delimiter so `$1`, `$@`, and `$VAR` are never expanded by the parent shell:

```bash
cat <<'EOF' > run.sh
#!/usr/bin/env bash
echo "Executing target: $1"
echo "All arguments: $@"
EOF
chmod +x run.sh
```
