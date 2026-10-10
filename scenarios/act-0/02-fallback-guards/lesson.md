# Tactical Field Manual: Default Fallbacks & Guards

## 1. The Mental Model (Parameter Expansion Operators)
In modern automated systems, scripts frequently run in diverse environments (local dev, CI test runners, production clusters). 
Writing verbose 5-line `if [ -z "$PORT" ]; then PORT=8080; fi` checks creates visual noise and violates defensive shell discipline.

Bash provides native, in-memory **Parameter Expansion** operators that handle defaults and validation without spawning subshells or subprocesses.

| Expansion | Behavior |
| :--- | :--- |
| `${VAR:-default}` | If `VAR` is unset or empty, evaluate to `default`. `VAR` remains unchanged. |
| `${VAR:=default}` | If `VAR` is unset or empty, set `VAR` to `default` and evaluate to `default`. |
| `${VAR:?error_msg}` | If `VAR` is unset or empty, print `error_msg` to `stderr` and **exit immediately with status 1**. |
| `${VAR:+alt_val}` | If `VAR` is set and non-empty, evaluate to `alt_val`; otherwise evaluate to empty string. |

---

## 2. Syntax Cheatsheet: Common Patterns
```bash
# Provide safe fallback values for optional config
PORT="${PORT:-8080}"
DB_HOST="${DB_HOST:-localhost}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Enforce mandatory secrets or critical paths
API_KEY="${API_KEY:?API_KEY is required to boot microservice}"
DATABASE_URL="${DATABASE_URL:?DATABASE_URL must be specified}"
```

> **Why the colon (`:`) matters**:
> - `${VAR-default}` checks only if `VAR` is *unset*. If `VAR=""` (empty string), it keeps the empty string!
> - `${VAR:-default}` checks if `VAR` is *unset OR empty*. This is almost always what you want in production scripts.

---

## 3. Deadly Pitfall in Automated Deployments
Under `set -u` (nounset), referencing an unset variable directly causes Bash to crash:
```bash
set -u
echo "Starting on port $PORT"   # CRASH: bash: PORT: unbound variable
```
By using `${PORT:-8080}`, Bash safely resolves the default even with `set -u` enabled.

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `Parameter Expansion`)
* Greg's Bash Wiki: [ParameterExpansion](https://mywiki.wooledge.org/ParameterExpansion)
* GNU Bash Reference Manual: Section 3.5.3 (Shell Parameter Expansion)

---

## 5. Mission Objective
Edit `env_injector.sh` in your sandbox workspace.
1. Provide defaults for `PORT` (`8080`) and `DB_HOST` (`localhost`) using `${VAR:-default}`.
2. Guard `API_SECRET` so that if it is missing or empty, execution terminates with the error `"API_SECRET is required"` using `${VAR:?error_msg}`.
3. Test your solution with `[4] Run State Verification`.
