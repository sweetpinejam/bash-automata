# Tactical Field Manual: Heredoc Template Forge (`<<EOF` vs `<<'EOF'`)

## 1. The Mental Model (Multi-Line Text in POSIX Shell)
When generating configuration files (NGINX, Docker Compose, Systemd units, JSON/YAML), chaining 20 `echo "line" >> file` commands is slow and painful.

Unix shells provide **Here Documents (Heredocs)**:
```bash
cat <<EOF > output.txt
Line 1
Line 2
EOF
```

The critical rule of Heredocs hinges on whether the **delimiter token** (`EOF`) is quoted or unquoted:

```
               Unquoted: <<EOF                   Quoted: <<'EOF'
        ┌──────────────────────────────┐  ┌──────────────────────────────┐
        │ Variables expand: $VAR       │  │ Literal text: $VAR stays     │
        │ Command substitutions run    │  │ NO expansions whatsoever     │
        │ Literal $ must be escaped \$ │  │ Exact verbatim raw output    │
        └──────────────────────────────┘  └──────────────────────────────┘
```

---

## 2. When to Use Which Heredoc Type

### Case A: Quoted Delimiter `<<'EOF'` (Generating Scripts or Raw Configs)
Use this when you are generating a secondary Bash script, NGINX config with regexes, or code where you want all `$1`, `$@`, `$VAR`, and backticks to remain **literal**:
```bash
cat <<'EOF' > deploy.sh
#!/bin/bash
echo "Deploying version $1 for user $USER"
EOF
# The output file will contain literal "$1" and literal "$USER"!
```

### Case B: Unquoted Delimiter `<<EOF` (Dynamic Templating)
Use this when you want your script's variables to be injected into the template:
```bash
APP="my-service"
PORT=8080

cat <<EOF > service.conf
[Service]
ExecStart=/usr/bin/$APP --port=$PORT
ExecReload=/bin/kill -HUP \$MAINPID
EOF
# Notice that $APP and $PORT are replaced, while \$MAINPID remains literal!
```

---

## 3. Tab Stripping with `<<-EOF`
If you indent your heredoc inside a function or if-statement using **hard tab characters** (ASCII 9), starting the heredoc with `<<-` strips all leading tabs:
```bash
if true; then
	cat <<-EOF
	This text has tabs stripped from the front.
	EOF
fi
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `Here Documents`)
* Greg's Bash Wiki: [Here Documents](https://mywiki.wooledge.org/BashGuide/InputAndOutput#Here_Documents)
* Linux Shell Scripting Tutorial: Heredoc syntax and quoting rules

---

## 5. Mission Objective
Edit `forge.sh` in your sandbox. 
1. Use an unquoted heredoc with escaped `\$MAINPID` for `service.conf`.
2. Use a quoted heredoc `<<'EOF'` for `run.sh` to preserve literal `$1`.
Verify with `[4] Run State Verification`.
