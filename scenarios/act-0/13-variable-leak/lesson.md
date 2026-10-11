# Tactical Field Manual: The Variable Leak (Function Scoping & `local` Defense)

## 1. Systems Mental Model: The Global Scope Trap in Shell Functions
In Python, C, Go, and JavaScript, functions create a private local scope by default:
```python
def process():
    i = 10  # Local variable, does not touch outer 'i'
```
In Bash, **all variable assignments are GLOBAL by default**, even when written inside a function body:

```bash
process() {
    i=10  # 💥 MODIFIES THE GLOBAL 'i' IN THE ENTIRE SHELL SCRIPT!
}

for (( i=1; i<=5; i++ )); do
    process
    # The outer loop expects i=1, but process() mutated i to 10!
    # The loop terminates immediately after a single iteration!
done
```

This shell behavior is called **Global Scope Pollution**. It is one of the most insidious bugs in production shell programming, causing loops to terminate early, configs to be overwritten, and state machines to enter invalid states.

---

## 2. Syntax Anatomy: The `local` Keyword

To declare a variable with private function scope, you must explicitly use the **`local` built-in**:

```bash
process_day() {
    local day_id="$1"
    local chunk_index
    local temp_file="spool_${day_id}.tmp"

    for chunk_index in {1..3}; do
        # Mutating chunk_index here is 100% safe!
        # It exists only on the function call stack!
    done
}
```

### Critical Rules for `local`:
1. **Functions Only**: The `local` keyword can **only** be used inside a function body. Using `local` in the top-level script body is an error.
2. **Declaration & Assignment Quoting**:
   ```bash
   # ✅ BEST PRACTICE: Separate declaration and assignment or quote expansions:
   local result
   result=$(calculate_checksum "$file")

   # Or in one line with quotes:
   local result="$(calculate_checksum "$file")"
   ```
3. **Dynamic Scoping**: Bash uses **dynamic scoping**, not lexical scoping. If function `A` declares `local x=1` and calls function `B`, function `B` can see and modify `x` unless `B` also declares its own `local x`! Always declare `local` in every function that uses a variable.

---

## 3. Comparison: Scope Lifetime in Bash

| Declaration | Scope Lifetime | Visible in Child Functions? | Overwrites Outer State? |
| :--- | :--- | :---: | :---: |
| `var="value"` | **Global** (Entire script lifecycle) | Yes | 💥 **YES** (Overwrites caller) |
| `local var="value"` | **Call Stack** (Until function returns) | Yes (Dynamic) | 🛡️ **NO** (Caller protected) |
| `readonly var="value"` | **Global Immutable** | Yes | Cannot be modified |
| `( var="value" )` | **Subshell** (Process memory) | In subshell only | 🛡️ **NO** (Process isolation) |

---

## 4. Architectural Diagram: Multi-Stage Archival Call Stack

```
[ Main Script Body ]
  ├── day_id = 1 (Global loop counter: 1..5)
  │
  ▼
  Call: archive_day "$day_id"
  ┌─────────────────────────────────────────────────────────────┐
  │ Function: archive_day                                       │
  │ local day="$1"                                              │
  │ local chunks_processed=0                                    │
  │                                                             │
  │ Call: process_chunks "$day"                                │
  │ ┌─────────────────────────────────────────────────────────┐ │
  │ │ Function: process_chunks                                │ │
  │ │ local chunk_id                                          │ │
  │ │ for chunk_id in 1 2 3; do                               │ │
  │ │     # Safe! Does NOT clobber day_id or day!            │ │
  │ │ done                                                    │ │
  │ └─────────────────────────────────────────────────────────┘ │
  │                                                             │
  │ Record day to backup_manifest.tsv                           │
  └─────────────────────────────────────────────────────────────┘
  │
  ▼
  Main Loop increments day_id -> continues smoothly to 5!
```

---

## 5. Self-Assessment Checklist
Before modifying `backup_bot.sh`:

1. **Why does an outer `for (( i=1; i<=5; i++ ))` loop terminate after one iteration if a helper function assigns `i=10`?**
   * *Answer*: Because without `local`, variables inside functions modify global shell memory, overwriting the outer loop's counter.
2. **Where can the `local` keyword be used?**
   * *Answer*: Strictly inside functions. Using `local` at the top level of a script throws a fatal error.
3. **What is dynamic scoping in Bash?**
   * *Answer*: A `local` variable declared in function `A` is accessible to any subordinate function `B` called by `A`, unless `B` declares its own `local` variable of the same name.
4. **How do you declare multiple local variables in a single statement?**
   * *Answer*: `local var1 var2 var3` or `local a="1" b="2"`.
5. **How can you ensure a local variable cannot be modified within the function?**
   * *Answer*: Use `local -r var="val"` or `readonly var="val"`.

---

## 6. Mission Objectives
Implement `backup_bot.sh` as a modular multi-day snapshot manager:
1. Accept optional `--days <N>` argument (default: 5).
2. Modular function design:
   - `process_day_chunks()`: processes 3 chunks (1..3) per day. All loop counters and paths must be declared `local`.
   - `archive_day()`: coordinates daily archival and writes an entry to `backup_manifest.tsv`. All variables must be declared `local`.
3. Ensure zero global scope leaks: verify that loop counters `day_id` and `chunk_id` do not collide.
4. Process all N days (default: 5 days, totaling 15 chunks).
5. Generate `backup_manifest.tsv` with tab-separated columns:
   `DAY\tCHUNKS\tSTATUS`
6. Output summary: `BACKUP_BOT_COMPLETE: days=<N>, total_chunks=<T>, manifest=<path>`.
