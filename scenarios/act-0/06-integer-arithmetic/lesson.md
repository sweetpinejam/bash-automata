# Tactical Field Manual: Integer Arithmetic & High-Throughput Aggregation

## 1. Systems Mental Model: The Subshell Arithmetic Anti-Pattern
In legacy shell scripts, you will frequently find:
```bash
# ❌ THE EXPR / BC FORK-BOMB:
count=0
while read line; do
    count=$(expr $count + 1)     # FORKS A SUBSHELL ON EVERY LINE!
done < data.log
```
Every invocation of `$(expr ...)` forces the operating system to fork a new process, load `/usr/bin/expr` from disk, dynamic-link libc, execute the instruction, and tear down the process.
Processing 5,000 log lines with `expr` takes **15+ seconds** and wastes millions of CPU cycles.

### Native Bash In-Memory Arithmetic
Bash contains a built-in C-style arithmetic evaluator that operates in native CPU registers:
```bash
# ✅ PURE BASH ARITHMETIC ($O(1) Kernel Overhead):
count=0
while read -r line; do
    (( count++ ))
done < data.log
```
This processes 5,000 increments in **under 15 milliseconds**—1,000x faster than `expr`.

---

## 2. Syntax Comparison: `(( ... ))` vs `$(( ... ))`

Bash provides two primary forms for integer arithmetic:

| Syntax | Description | Returns | Use Case | Example |
| :--- | :--- | :--- | :--- | :--- |
| `(( expr ))` | Compound arithmetic command | Exit code (0 if true/non-zero, 1 if zero) | In-place mutations, loop counters, comparisons | `(( total += latency ))`<br>`(( count++ ))` |
| `$(( expr ))` | Arithmetic expansion | Expanded integer string | Variable assignment, CLI arguments, string interpolation | `avg=$(( total / count ))`<br>`echo "Pct: $(( a * 100 / b ))%"` |

### Key Rules Inside Arithmetic Expressions:
1. **Dollar Signs Are Optional**: You do not need `$VAR`. You can write `(( total = total + latency ))` instead of `(( total = $total + $latency ))`.
2. **Unset Variables Default to 0**: If `foo` is unset, `(( foo += 5 ))` initializes `foo` to 5 automatically.
3. **Integer Only**: Bash arithmetic is strictly 64-bit signed integer math. There are no floating-point numbers (`3 / 2` yields `1`).

---

## 3. The Fatal `set -e` Post-Increment Trap!

In modern production scripts using `set -euo pipefail`, the following line will **mysteriously crash your script**:
```bash
set -e
count=0
(( count++ ))  # 💥 SCRIPT CRASHES HERE! WHY?
```

### The Post-Increment Return Value Trap
In C and Bash, `count++` returns the **value before incrementing**.
1. When `count=0`, the expression `count++` evaluates to `0`.
2. In POSIX arithmetic, an expression evaluating to `0` returns an **exit status of 1 (failure)**!
3. Because `set -e` is active, the non-zero exit status triggers immediate process termination!

### How to Safely Increment Under `set -e`:
```bash
# Solution 1: Use pre-increment (evaluates to 1):
(( ++count ))

# Solution 2: Use in-place addition:
(( count += 1 ))

# Solution 3: Append fallback:
(( count++ || 1 ))
```

---

## 4. Integer Mathematics: Percentages & Fixed-Point Decimals

Because Bash does not support floating-point division, calculating percentages requires **multiplying before dividing** to preserve precision:

```bash
# ❌ INCORRECT (Truncates to 0):
pct=$(( (errors / total) * 100 ))  # errors / total is 0. 0 * 100 = 0!

# ✅ CORRECT (Scale up first):
pct=$(( (errors * 100) / total ))  # (5 * 100) / 1000 = 500 / 1000 = 0%?
                                   # (50 * 100) / 1000 = 5000 / 1000 = 5%

# ✅ FIXED-POINT (Tenths of a percent, e.g. 5.2%):
permille=$(( (errors * 1000) / total ))
whole=$(( permille / 10 ))
fraction=$(( permille % 10 ))
echo "Error Rate: ${whole}.${fraction}%"
```

---

## 5. Architectural Diagram: Real-Time Traffic Aggregator

```
[ Input: samples.log (status=200 latency_ms=45 size_bytes=1024) ]
                             │
                             ▼
              [ Line Parsing & Field Extraction ]
       status="${status_part##*=}"
       latency="${latency_part##*=}"
       bytes="${bytes_part##*=}"
                             │
                             ▼
              [ In-Memory Arithmetic Accumulation ]
       (( ++TOTAL_REQS ))
       (( TOTAL_LATENCY += latency ))
       (( TOTAL_BYTES += bytes ))
       (( latency < MIN_LATENCY )) && MIN_LATENCY=$latency
       (( latency > MAX_LATENCY )) && MAX_LATENCY=$latency
       (( latency <= 200 )) && (( ++FAST_REQS ))
       Status bucketing: 2xx, 3xx, 4xx, 5xx
                             │
                             ▼
              [ Final Metric Derivation ($(( ... ))) ]
       AVG_LATENCY=$(( TOTAL_LATENCY / TOTAL_REQS ))
       SLA_PCT=$(( (FAST_REQS * 100) / TOTAL_REQS ))
       ERR_PCT=$(( (COUNT_5XX * 100) / TOTAL_REQS ))
                             │
                             ▼
              [ SLA Verdict & Rollup Output ]
       Write metrics_rollup.tsv
       Output AGGREGATOR_SUMMARY
```

---

## 6. Self-Assessment Checklist
Before modifying `aggregator.sh`:

1. **Why does `set -e` abort on `x=0; (( x++ ))`?**
   * *Answer*: Post-increment evaluates to `0` (the pre-increment value). In shell arithmetic, `0` returns exit status 1, triggering `set -e`.
2. **Why is `(( a += b ))` faster than `a=$(expr $a + $b)`?**
   * *Answer*: `(( ))` is an internal shell engine feature executed in RAM; `expr` spawns an external process via `fork`/`execve`.
3. **How do you calculate a percentage in integer arithmetic without losing decimals to zero-truncation?**
   * *Answer*: Multiply the numerator by 100 (or 1000) before dividing by the denominator.
4. **Do you need `$` in front of variable names inside `(( ... ))`?**
   * *Answer*: No. Variable names are treated directly as numeric identifiers inside `(( ))`.
5. **How does Bash evaluate the conditional ternary operator in arithmetic?**
   * *Answer*: Like C: `(( max = a > b ? a : b ))`.

---

## 7. Mission Objectives
Implement `aggregator.sh` as a high-throughput traffic and SLA analyzer:
1. Accept input log file as `$1` (default: `samples.log`).
2. Strictly no external math commands: no `expr`, `bc`, `awk`, `dc`, `python`.
3. Parse lines containing: `timestamp=<ts> method=<m> status=<s> latency_ms=<l> size_bytes=<b>`.
4. Accumulate:
   - `TOTAL_REQS`, `COUNT_2XX`, `COUNT_3XX`, `COUNT_4XX`, `COUNT_5XX`.
   - `TOTAL_LATENCY`, `MIN_LATENCY`, `MAX_LATENCY`, `AVG_LATENCY`.
   - `TOTAL_BYTES`.
   - `SLA_COMPLIANCE_PCT` (requests where `latency_ms <= 200`).
   - `ERROR_PCT` (percentage of requests with `status >= 500`).
5. Determine operational verdict:
   - If `COUNT_5XX > 0` and `ERROR_PCT >= 5`: `SLA_BREACH_HIGH_ERRORS`
   - Else if `AVG_LATENCY > 300`: `SLA_BREACH_HIGH_LATENCY`
   - Else: `HEALTHY_SLA_MET`
6. Write formatted report to `metrics_rollup.tsv`.
7. Output summary: `AGGREGATOR_SUMMARY: reqs=<N>, avg_latency=<A>ms, min=<Min>ms, max=<Max>ms, err_pct=<E>%, sla=<S>%, verdict=<V>`.
