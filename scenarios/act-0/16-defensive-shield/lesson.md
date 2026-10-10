# Tactical Field Manual: The Defensive Shield (`set -euo pipefail`)

## 1. The Mental Model (The Shell's Dangerous Defaults)
By default, Bash was designed for interactive terminal convenience, not mission-critical automated pipelines.
Its default behavior is remarkably forgiving—and dangerously silent:
1. **Silent Errors**: When a command fails, Bash prints an error to stderr and **keeps executing the next line** as if nothing happened!
2. **Silent Unbound Variables**: If you misspell a variable name (`rm -rf "$TMP_DRE/*"` instead of `$TMP_DIR`), Bash replaces the missing variable with an empty string, transforming your command into `rm -rf /*`!
3. **Pipeline Concealment**: In a pipeline (`cmd1 | cmd2 | cmd3`), Bash reports only the exit status of the *last* command (`cmd3`). If `cmd1` crashes, Bash reports exit code 0!

---

## 2. The Defensive Shield (`set -euo pipefail`)

Every professional Bash script begins with the four flags of the Defensive Shield:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

### What Each Flag Does:
* **`-e` (`errexit`)**: Exit immediately if any command exits with a non-zero status.
* **`-u` (`nounset`)**: Treat unset/unbound variables as an error and exit immediately.
* **`-o pipefail`**: Return value of a pipeline is the status of the *last command to exit with a non-zero status* (or 0 if all succeeded).
* **`-x` (`xtrace`, optional)**: Print commands and their arguments as they are executed (essential for CI debugging).

---

## 3. Syntax Cheatsheet: Working Safely with `-euo pipefail`

```bash
# 1. Tolerating expected non-zero exits under set -e:
grep "needle" haystack.txt || true

# 2. Providing defaults for optional variables under set -u:
PORT="${PORT:-8080}"

# 3. Guarding pipelines under pipefail:
curl -fsSL https://api.service/data | jq . | gzip > out.gz
# If curl or jq fails, the pipeline fails immediately!
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `set [-abefhkmnptuvxBCEHPT]`)
* Better Bash Scripting: [Use set -euo pipefail](https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/)
* Greg's Bash Wiki: [BashFAQ/105: Why doesn't set -e work as expected?](https://mywiki.wooledge.org/BashFAQ/105)

---

## 5. Mission Objective
Edit `deploy.sh` in your sandbox. Add `set -euo pipefail` so that misconfigured variables and pipeline failures abort the deploy before dangerous downstream steps run.
Verify with `[4] Run State Verification`.
