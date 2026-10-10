# Tactical Field Manual: The Variable Leak (Function Scoping & `local`)

## 1. The Mental Model (All Shell Variables Are Global)
In Python, JavaScript, and C, variables declared inside functions belong to that function's local frame.
In Bash, **all variables assigned anywhere are global by default**!

Consider:
```bash
my_helper() {
    count=10
}

count=1
my_helper
echo "$count"   # Outputs 10! The function silently mutated global state.
```

If your function uses common index names like `i`, `count`, `file`, or `temp`, calling that function inside a loop will overwrite the loop's state, resulting in infinite loops or mysterious early exits.

---

## 2. The Solution: The `local` Keyword
Always declare internal variables using `local` at the top of your functions:

```bash
process_backup() {
    local day_id="$1"
    local chunk
    local temp_file="/tmp/stage_$day_id.tmp"

    for chunk in {1..5}; do
        # chunk and day_id exist ONLY while process_backup is running
        ...
    done
}
```

When `process_backup` returns, the local variables are cleaned up and the caller's variables remain completely untouched.

---

## 3. Best Practice: Combining `local` with Parameter Expansions
```bash
deploy_app() {
    local app_name="${1:?app_name required}"
    local port="${2:-8080}"
    local retries=3
    ...
}
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `local [option] [name[=value] ...]`)
* Greg's Bash Wiki: [Functions: Scope](https://mywiki.wooledge.org/BashGuide/Functions#Scope)
* Google Shell Style Guide: Section 5.3 (Local Variables)

---

## 5. Mission Objective
Edit `backup_bot.sh` in your sandbox. Scope `day_id` with `local day_id` inside `process_backup_day()` so the outer loop completes all 5 days cleanly into `backup_report.txt`.
