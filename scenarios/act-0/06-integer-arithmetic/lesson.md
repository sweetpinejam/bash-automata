# Tactical Field Manual: Integer Arithmetic

## 1. The Mental Model (Built-in Math vs `expr` Subshells)
In Unix history before POSIX standards solidified, shell math was outsourced to an external program: `/usr/bin/expr`.
Writing:
```bash
COUNT=$(expr $COUNT + 1)
```
does the following on every iteration of a loop:
1. Shell invokes `fork()` to clone the process.
2. Shell executes `execve("/usr/bin/expr", ...)` to load the binary into memory.
3. Kernel schedules the `expr` process.
4. Process writes output to a pipe and terminates with `exit()`.
5. Parent shell reads the pipe and reaps the child with `wait()`.

Doing this inside a loop processing 5,000 metrics causes catastrophic CPU slowdown.

Bash features built-in **C-style 64-bit integer arithmetic** executed in-memory:
- **`(( ... ))`** : Arithmetic Command (evaluates expressions, returns 0 if non-zero, 1 if zero).
- **`$(( ... ))`** : Arithmetic Expansion (evaluates expression and replaces itself with the calculated numeric string).

---

## 2. Syntax Cheatsheet: Arithmetic Expressions

```bash
# 1. Increments and assignments inside (( ... )):
(( count++ ))
(( count += 5 ))
(( total_latency += latency ))

# 2. Variable syntax inside arithmetic:
# Variables DO NOT need a dollar sign ($) inside (( )) or $(( )):
(( x = a * b + c ))

# 3. Arithmetic expansions for capturing output:
avg_latency=$(( total_latency / count ))
percent=$(( (errors * 100) / total ))

# 4. Arithmetic comparisons inside if:
if (( count > 0 )); then
    echo "Active traffic detected"
fi

if (( status >= 500 )); then
    echo "Server error encountered"
fi
```

---

## 3. Deadly Pitfall: The `(( count++ ))` Trap Under `set -e`
Here is a famous bug that catches even senior Linux engineers:
```bash
set -e
count=0
(( count++ ))   # 💥 SCRIPT CRASHES AND EXITS IMMEDIATELY!
```
**Why did it crash?**
1. Post-increment (`count++`) returns the **original** value before incrementing, which is `0`.
2. In Bash arithmetic, if the expression evaluates to `0`, the command exit status is `1` (failure).
3. Because `set -e` is active, exit status `1` causes Bash to abort the script immediately!

**The Bulletproof Fix**:
Use pre-increment or addition assignment:
```bash
(( ++count ))       # Evaluates to 1 -> Exit code 0 (Safe under set -e)
(( count += 1 ))    # Evaluates to 1 -> Exit code 0 (Safe under set -e)
```

In addition, Bash arithmetic only handles **integers**. Decimal fractions are truncated towards zero (e.g., `5 / 2` evaluates to `2`). Always guard against division by zero:
```bash
# Guard before division:
avg=0
if (( count > 0 )); then
    avg=$(( total / count ))
fi
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `ARITHMETIC EVALUATION`)
* Greg's Bash Wiki: [Arithmetic Expression](https://mywiki.wooledge.org/ArithmeticExpression)
* GNU Bash Reference Manual: Section 6.5 (Shell Arithmetic)

---

## 5. Mission Objective
Edit `aggregator.sh` in your sandbox. Replace all `expr` calls with native `(( ... ))` and `$(( ... ))` to aggregate `samples.log` into `summary.txt` with zero subprocess forks.
