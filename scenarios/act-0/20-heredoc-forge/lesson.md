# Tactical Field Manual: The Heredoc Template Forge (`<<EOF`, `<<'EOF'`, & `<<-EOF`)

## 1. Systems Mental Model: The Configuration Templating Dilemma
In systems infrastructure engineering, scripts frequently provision multi-line configuration manifests:
* Systemd service units (`.service`)
* NGINX / Envoy reverse proxy configurations (`.conf`)
* Docker Compose files (`docker-compose.yml`)
* Shell wrapper scripts (`run.sh`)
* Structured data manifests (`JSON`, `YAML`, `TOML`)

In amateur scripts, developers chain dozens of `echo "..." >> file` statements. This is:
* **Slow and error-prone**: Each `>>` invocation repeatedly opens and closes the file descriptor.
* **Unreadable**: Escaping quotes on every line obscures the actual configuration syntax.
* **Dangerous**: Unintended variable expansion corrupts downstream configuration directives.

Unix shells solve this with **Here Documents (Heredocs)**. However, mastering Heredocs requires understanding the exact rules governing **delimiter token quoting and tab stripping**.

---

## 2. Syntax Matrix: The Three Heredoc Modalities

| Syntax | Delimiter Type | Variable & Command Expansion | Indentation Stripping | Primary Production Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **`cat <<EOF`** | Unquoted | **YES** (`$VAR`, `$(cmd)`) | NO | Templated configs requiring variable injection |
| **`cat <<'EOF'`** | Quoted | **NO** (Literal raw verbatim) | NO | Generating secondary shell scripts, Python files, regexes |
| **`cat <<-EOF`** | Tab-stripped | **YES** (or NO if `<<-'EOF'`) | **YES** (Leading tabs stripped) | Cleanly indented heredocs inside functions & conditionals |

---

## 3. Delimiter Deep-Dive

### Modality 1: Unquoted Delimiter `<<EOF` (Dynamic Templating)
When the delimiter word is unquoted, Bash treats the heredoc body like double-quoted text:
* Shell variables (`$APP_NAME`, `${PORT}`) expand.
* Arithmetic (`$(( PORT + 1 ))`) evaluates.
* Command substitutions (`$(date)`) execute.

#### The Escaping Rule:
If your configuration template contains literal tokens that start with `$` (such as Systemd's `$MAINPID` or NGINX's `$uri`), you **MUST escape the dollar sign with a backslash**:
```bash
cat <<EOF > service.conf
[Service]
ExecStart=/usr/bin/$APP_NAME --port=$PORT
ExecReload=/bin/kill -HUP \$MAINPID
EOF
```
* `$APP_NAME` and `$PORT` expand to their shell variable values.
* `\$MAINPID` is written as literal `$MAINPID` into `service.conf`.
* If unescaped, Bash attempts to expand `$MAINPID`. Since `MAINPID` is unset, Bash silently replaces it with an empty string: `ExecReload=/bin/kill -HUP `!

---

### Modality 2: Quoted Delimiter `<<'EOF'` (Raw Verbatim Code Generation)
If the delimiter is enclosed in single quotes (`'EOF'`) or double quotes (`"EOF"`), **all variable, command, and parameter expansions are completely disabled**:
```bash
cat <<'EOF' > run.sh
#!/usr/bin/env bash
echo "Executing target: $1 with arguments: $@"
EOF
chmod +x run.sh
```
* `$1` and `$@` remain literal `$1` and `$@` in `run.sh`.
* You do not need to escape anything—backticks, dollar signs, and quotes are written 100% verbatim.

---

### Modality 3: Tab-Stripping Delimiter `<<-EOF` (Clean Code Indentation)
In standard heredocs, the closing delimiter `EOF` must appear flush against the left margin (column 0). If you indent your code inside a function:
```bash
# 💥 FATAL SYNTAX ERROR:
configure_proxy() {
    cat <<EOF > proxy.conf
    server {
        listen 80;
    }
    EOF  # <-- Shell cannot find matching "EOF" because of indentation!
}
```
Bash fails with: `syntax error: unexpected end of file (looking for matching "EOF")`.

To solve this, use `<<-EOF` and indent using **hard TAB characters** (ASCII 9):
```bash
configure_proxy() {
	cat <<-EOF > proxy.conf
	server {
		listen 80;
	}
	EOF
}
```
* `<<-` strips all **leading TAB characters** from both the content lines and the closing delimiter.
* The output file `proxy.conf` begins flush at the margin, while your source code remains indented and readable.
* > [!CAUTION] `<<-` ONLY strips hard TAB characters (`\t`). It does **NOT** strip leading spaces!

---

## 4. Architectural Diagram: Heredoc Template Forge Pipeline

```
                     [ forge.sh Invocation ]
                                │
         ┌──────────────────────┼──────────────────────┐
         ▼                      ▼                      ▼
  [ 1. Systemd Unit ]    [ 2. Indented Proxy ]   [ 3. Runner Script ]
   cat <<EOF              cat <<-EOF              cat <<'EOF'
   (Unquoted)             (Tab-stripped)          (Quoted Literal)
         │                      │                      │
   Interpolates $APP      Strips leading \t       Preserves raw $1, $@
   Escapes \$MAINPID      Interpolates $PORT      Zero expansions
         │                      │                      │
         ▼                      ▼                      ▼
  [ service.conf ]         [ proxy.conf ]          [ run.sh (chmod +x) ]
         │                      │                      │
         └──────────────────────┼──────────────────────┘
                                │
                                ▼
                   [ 4. forge_manifest.json ]
                    Record artifacts & sizes
```

---

## 5. Self-Assessment Checklist
Before modifying `forge.sh`:

1. **What happens to `$MAINPID` in an unquoted heredoc (`<<EOF`) if you do not escape the `$`?**
   * *Answer*: Bash treats it as a shell parameter and expands it to an empty string, corrupting the generated configuration.
2. **How does quoting the delimiter (`<<'EOF'`) alter heredoc behavior?**
   * *Answer*: It disables all parameter expansions, command substitutions, and arithmetic, writing the body 100% verbatim.
3. **What is the difference between `<<EOF` and `<<-EOF`?**
   * *Answer*: `<<-EOF` strips all leading TAB characters from the content and closing delimiter.
4. **Why does `<<-EOF` fail to strip indentation if you indent with spaces instead of tabs?**
   * *Answer*: The POSIX standard strictly defines `<<-` to strip only ASCII TAB characters (`\t`), ignoring space characters (`0x20`).
5. **When generating a secondary Bash script, which heredoc style should you prefer and why?**
   * *Answer*: Quoted heredoc (`<<'EOF'`), because it guarantees that positional parameters (`$1`, `$@`) and variables in the generated script are not prematurely expanded.

---

## 6. Mission Objectives
Implement `forge.sh` as a multi-format configuration forge:
1. Enable `set -euo pipefail`.
2. Accept parameters:
   - `APP_NAME="${1:-${APP_NAME:-telemetry-collector}}"`
   - `PORT="${2:-${PORT:-9090}}"`
3. Generate `service.conf` using an unquoted heredoc (`<<EOF`):
   - Interpolate `$APP_NAME` and `$PORT`.
   - Backslash-escape `\$MAINPID` in the `ExecReload` directive: `ExecReload=/bin/kill -HUP \$MAINPID`.
4. Generate `proxy.conf` inside a function using a tab-stripped heredoc (`<<-EOF`):
   - Indent the heredoc block using leading tab characters.
   - Interpolate `$PORT` into `proxy_pass http://127.0.0.1:$PORT;`.
5. Generate `run.sh` using a quoted heredoc (`<<'EOF'`):
   - Preserve literal `$1` and `$@`.
   - Make `run.sh` executable via `chmod +x run.sh`.
6. Catalog generated files and their byte sizes into `forge_manifest.json`.
7. Output summary log: `FORGE_COMPLETE: artifacts=3, app=$APP_NAME, port=$PORT, status=SUCCESS`.
