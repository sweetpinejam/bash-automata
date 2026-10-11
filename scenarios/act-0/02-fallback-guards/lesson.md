# Tactical Field Manual: Default Fallbacks, Guards & Secret Cascading

## 1. Systems Mental Model: The Parameter Expansion Matrix
In production shell automation, hardcoding configuration values leads to brittle scripts that break across environments (development, CI test, staging, production). Relying on external template engines like Jinja2 or `envsubst` introduces external dependencies.

POSIX Bash provides an ultra-fast, native, in-memory configuration engine: **Parameter Expansion**.

Every parameter expansion executes entirely within shell memory without spawning subprocesses (`execve`).

### The Colon vs. Non-Colon Distinction
The most common trap in parameter expansion is the distinction between a variable that is **unset** vs a variable that is **set to an empty string (`""`)**:

| Syntax | Condition: `VAR` is Unset | Condition: `VAR=""` (Empty) | Condition: `VAR="val"` (Set) |
| :--- | :--- | :--- | :--- |
| `${VAR:-default}` | Uses `"default"` | Uses `"default"` | Uses `"val"` |
| `${VAR-default}` | Uses `"default"` | Uses `""` (Empty string!) | Uses `"val"` |
| `${VAR:=default}` | Sets & Uses `"default"` | Sets & Uses `"default"` | Uses `"val"` |
| `${VAR=default}` | Sets & Uses `"default"` | Uses `""` (Empty string!) | Uses `"val"` |
| `${VAR:?error}` | Aborts script with `error` | Aborts script with `error` | Uses `"val"` |
| `${VAR?error}` | Aborts script with `error` | Uses `""` (Empty string!) | Uses `"val"` |
| `${VAR:+alt}` | Expands to nothing (`""`) | Expands to nothing (`""`) | Uses `"alt"` |
| `${VAR+alt}` | Expands to nothing (`""`) | Uses `"alt"` | Uses `"alt"` |

> [!IMPORTANT]
> Always use the **colon form** (`:-`, `:=`, `:?`, `:+`) unless you specifically intend an empty string `""` to be treated as a valid, intentional configuration value.

---

## 2. Defensive Parameter Assertions (`:?`)
Under `set -u` (or `set -o nounset`), referencing an unset variable aborts the script. However, the default error message is cryptic:
```bash
./deploy.sh: line 14: API_SECRET: unbound variable
```
Worse, if `API_SECRET=""` (set but empty), `set -u` does not trigger! The script continues running with an empty secret, causing silent authentication failures or security holes downstream.

Using the guard operator `${VAR:?message}`:
```bash
: "${API_SECRET:?FATAL: API_SECRET is required but was unset or empty}"
```
1. The leading `:` is the shell **null built-in** (does nothing, evaluates arguments, exits 0).
2. If `API_SECRET` is unset or empty, Bash prints `FATAL: API_SECRET is required...` to `stderr` and terminates the process immediately with exit code 1.

---

## 3. Alternate Value Substitution (`:+`)
The alternate operator `${VAR:+alternate}` is used to dynamically inject flags or derived settings:
```bash
# If PROMETHEUS_ENDPOINT is set, enable metrics export:
METRICS_ENABLED="${PROMETHEUS_ENDPOINT:+true}"
METRICS_ENABLED="${METRICS_ENABLED:-false}"

# Conditionally append a CLI flag:
DEBUG_FLAG="${VERBOSE:+--verbose}"
curl $DEBUG_FLAG https://api.internal/health
```

---

## 4. Systems Architecture: The Config Compiler Pattern

```
[ Incoming Environment Variables ]
(PORT, DB_HOST, DB_PORT, API_SECRET, CLUSTER_NAME, PROMETHEUS_ENDPOINT)
                        │
                        ▼
           [ 1. Fallback Assignment ]
   PORT="${PORT:-8080}"
   DB_HOST="${DB_HOST:-127.0.0.1}"
   DB_PORT="${DB_PORT:-5432}"
   LOG_LEVEL="${LOG_LEVEL:-INFO}"
                        │
                        ▼
           [ 2. Mandatory Guardrails ]
   : "${API_SECRET:?API_SECRET is required}"
   : "${CLUSTER_NAME:?CLUSTER_NAME is required}"
                        │
                        ▼
           [ 3. Alternate Substitutions ]
   METRICS_ENABLED="${PROMETHEUS_ENDPOINT:+true}"
   METRICS_ENABLED="${METRICS_ENABLED:-false}"
                        │
                        ▼
           [ 4. Numeric Range Validation ]
   [[ "$PORT" =~ ^[0-9]+$ ]] && 1024 <= PORT <= 65535
                        │
                        ▼
           [ 5. Secure Disk Emission ]
   umask 077 && chmod 600 "$OUTPUT_FILE"
   Write compiled key-values to .env.runtime
                        │
                        ▼
           [ 6. Redacted Console Log ]
   Mask sensitive keys (API_SECRET=***REDACTED***)
```

---

## 5. Security Principles: Storing Secrets in Shell Runtimes
1. **File Permissions (`chmod 600`)**: Runtime environment files containing keys must be unreadable by other users on the host (`rw-------`). Use `chmod 600 "$OUT"` or set `umask 077` before writing.
2. **Log Sanitization**: Never output raw secret variables to standard output or CI/CD logs. Always redact keys containing `SECRET`, `PASSWORD`, `KEY`, or `TOKEN`.

---

## 6. Self-Assessment Checklist
Before coding `env_injector.sh`, test your comprehension:

1. **What is the difference between `${PORT:-8080}` and `${PORT-8080}` if `PORT=""`?**
   * *Answer*: `${PORT:-8080}` yields `"8080"`, while `${PORT-8080}` yields `""` (empty string).
2. **Why do we prefix mandatory assertions with the colon `:` command?**
   * *Answer*: `:` is the POSIX no-op command. It forces Bash to evaluate and expand the argument `${VAR:?error}` without attempting to execute the expanded string as a command.
3. **If `DEBUG` is unset, what does `echo "${DEBUG:+--debug}"` print?**
   * *Answer*: Nothing (empty string). If `DEBUG="1"`, it prints `"--debug"`.
4. **How do you validate that an expanded variable contains only numeric digits?**
   * *Answer*: Using Bash regex: `[[ "$VAR" =~ ^[0-9]+$ ]]`.
5. **Why should `.env.runtime` be created with `0600` permissions?**
   * *Answer*: To prevent unprivileged processes and local users from reading sensitive plaintext API credentials.

---

## 7. Mission Objectives
Refactor `env_injector.sh` into a complete, hardened environment compiler:
1. Parse optional `--output <file>` argument (default: `.env.runtime`).
2. Apply fallback defaults for `PORT` (8080), `DB_HOST` (127.0.0.1), `DB_PORT` (5432), `LOG_LEVEL` (INFO), and `TIMEOUT_SECONDS` (30).
3. Assert mandatory presence of `API_SECRET` and `CLUSTER_NAME` using `${VAR:?error}`; exit 1 with clear stderr message if missing.
4. Derive `METRICS_ENABLED`: set to `true` if `PROMETHEUS_ENDPOINT` is defined and non-empty, otherwise `false`.
5. Validate that `PORT` and `DB_PORT` are valid integers between 1024 and 65535; exit 1 if out of range.
6. Write the compiled configuration to the output file with permissions `0600`.
7. Output redacted summary to stdout: sensitive keys (matching `*SECRET*` or `*KEY*` or `*TOKEN*`) must be printed as `***REDACTED***`.
8. Output final line: `CONFIG_COMPILED: vars=<N>, masked=<M>, output=<path>`.
