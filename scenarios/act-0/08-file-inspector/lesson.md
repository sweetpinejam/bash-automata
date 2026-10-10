# Tactical Field Manual: The File Inspector (File Test Operators)

## 1. The Mental Model (Filesystem Introspection in POSIX Shell)
Production automated scripts should never blindly assume files exist, are readable, or are executable.
Attempting to run a script that lacks execute permissions (`chmod +x`) or trying to parse an empty zero-byte config results in catastrophic failure.

Bash provides native unary **File Test Operators** inside `[[ ... ]]`:

| Operator | Evaluates True If: | Common Automated Use Case |
| :--- | :--- | :--- |
| **`-e file`** | `file` exists (any type) | Basic existence check |
| **`-f file`** | `file` exists and is a **regular file** | Distinguishing real files from dirs/pipes |
| **`-d dir`** | `dir` exists and is a **directory** | Verifying destination folders exist |
| **`-s file`** | `file` exists and has **size > 0 bytes** | Detecting empty/corrupted configs |
| **`-x file`** | `file` exists and has **executable permissions** | Verifying binaries before launching |
| **`-r file`** | `file` exists and has **read permissions** | Verifying credentials/secrets readable |
| **`-w file`** | `file` exists and has **write permissions** | Checking log directories are writable |

---

## 2. Syntax Cheatsheet: Common Patterns

```bash
# Check if config exists AND is non-empty:
if [[ ! -s "/etc/app.conf" ]]; then
    echo "ERROR: Config missing or empty" >&2
    exit 1
fi

# Check if directory exists before writing to it:
if [[ ! -d "/var/log/app" ]]; then
    mkdir -p "/var/log/app"
fi

# Check if binary can be executed:
if [[ ! -x "/usr/local/bin/runner" ]]; then
    echo "ERROR: Runner binary not executable" >&2
    exit 1
fi
```

---

## 3. Deadly Pitfall: `-e` vs `-s`
Checking `-e file` only checks if the file inode exists.
If a previous failed process left behind an empty `0-byte` file (`touch app.conf` or truncated output), `-e` passes!
In automation pipelines, almost always prefer **`-s`** to ensure the file has actual content.

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `CONDITIONAL EXPRESSIONS`)
* Greg's Bash Wiki: [File Test Operators](https://mywiki.wooledge.org/BashFAQ/031#File_tests)
* Linux Filesystem Hierarchy: POSIX Inode Types

---

## 5. Mission Objective
Edit `preflight.sh` in your sandbox. Implement validation using `[[ ! -s "$config_file" ]]`, `[[ ! -d "$release_dir" ]]`, and `[[ ! -x "$app_bin" ]]`.
Verify that your script passes all valid checks and fails appropriately on invalid states using `[4] Run State Verification`.
