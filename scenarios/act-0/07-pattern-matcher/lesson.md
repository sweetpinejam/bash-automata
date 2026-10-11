# Tactical Field Manual: Pattern Matching in `[[ ]]` (Globs, Regex & `BASH_REMATCH`)

## 1. Systems Mental Model: The In-Process POSIX Regex Engine
In typical shell scripts, developers extract tokens using `grep`, `awk`, and `sed`:
```bash
# ❌ THE SLOW PIPELINE ANTI-PATTERN:
while read line; do
    ip=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    port=$(echo "$line" | awk '{print $4}')
done < firewall.log
```
This spawns 2 to 3 subprocesses per line, crippling throughput.

### Native POSIX Regex Engine in Bash
Bash links directly against your Linux system's POSIX C library regex engine (`regcomp(3)`, `regexec(3)`). When you use:
```bash
[[ "$line" =~ $pattern ]]
```
1. No external binary is executed. No subshells or pipes are created.
2. The expression evaluates in native process memory.
3. Successful matches populate the special shell array variable **`BASH_REMATCH`**.

---

## 2. Syntax Anatomy: `BASH_REMATCH` Capture Groups

When a regex containing parentheses `( ... )` matches a string, Bash assigns the captured sub-expressions to the `BASH_REMATCH` array:

```
[ Match: ALERT ip=192.168.1.50 port=443 reason=SQL_INJECTION ]
                             │
            pattern='^ALERT ip=([0-9.]+) port=([0-9]+) reason=([A-Z_]+)'
                             │
                             ▼
  ${BASH_REMATCH[0]}  ─── Entire matched string
  ${BASH_REMATCH[1]}  ─── First capture group  ("192.168.1.50")
  ${BASH_REMATCH[2]}  ─── Second capture group ("443")
  ${BASH_REMATCH[3]}  ─── Third capture group  ("SQL_INJECTION")
```

```bash
line="ALERT ip=10.0.0.1 port=22 reason=BRUTE_FORCE"
regex='^ALERT ip=([0-9.]+) port=([0-9]+) reason=([A-Z_]+)'

if [[ "$line" =~ $regex ]]; then
    ip="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[2]}"
    reason="${BASH_REMATCH[3]}"
    echo "Threat detected from $ip on port $port: $reason"
fi
```

---

## 3. The Fatal Regex Quoting Trap!

The most dangerous pitfall in Bash regex matching is **quoting the regex pattern inside the brackets**:

```bash
# ❌ BROKEN: Quoting regex string treats metacharacters literally!
if [[ "$line" =~ "^ALERT [0-9]+" ]]; then
    # Bash searches for a literal caret '^', literal brackets '[', and '+'!
fi

# ✅ THE GOLD STANDARD: Store the regex pattern in an unquoted variable
pattern='^ALERT [0-9]+'
if [[ "$line" =~ $pattern ]]; then
    # Metacharacters are interpreted correctly by the regex engine!
fi
```
> [!IMPORTANT]
> Always define complex regular expressions in a separate variable, and expand that variable **unquoted** on the right side of `=~`: `[[ "$string" =~ $pattern ]]`.

---

## 4. Glob Matching (`==`) vs Regular Expressions (`=~`)

Use the right tool for the job:

| Feature | Glob Matching (`==`) | Regular Expressions (`=~`) |
| :--- | :--- | :--- |
| **Operators** | `*`, `?`, `[...]` | `^`, `$`, `+`, `?`, `*`, `( )`, `{n,m}` |
| **Performance** | Ultra-fast (microsecond) | Fast, but invokes POSIX regex parser |
| **Capture Groups** | None | Full support via `BASH_REMATCH` |
| **Best For** | File extensions, prefixes, subnet checks | Structured log parsing, data extraction |

### Combining Globs and Regex
```bash
# 1. Fast regex extraction:
if [[ "$line" =~ $alert_regex ]]; then
    ip="${BASH_REMATCH[1]}"

    # 2. Fast glob subnet classification:
    if [[ "$ip" == 10.* || "$ip" == 192.168.* || "$ip" == 172.16.* ]]; then
        scope="INTERNAL"
    else
        scope="EXTERNAL"
    fi
fi
```

---

## 5. Architectural Diagram: Threat Classifier Pipeline

```
[ Input: firewall.log ]
          │
          ▼
[ while IFS= read -r line || [[ -n "$line" ]] ]
          │
          ├── 1. Regex Match: [[ "$line" =~ $pattern ]]
          │      └── If match fails: continue (ignore benign lines)
          │
          ├── 2. Extract Fields from BASH_REMATCH:
          │      ip="${BASH_REMATCH[1]}", port="${BASH_REMATCH[2]}", reason="${BASH_REMATCH[3]}"
          │
          ├── 3. Scope Classification (Globbing):
          │      [[ "$ip" == 10.* || "$ip" == 192.168.* ]] -> INTERNAL / EXTERNAL
          │
          ├── 4. Severity Routing:
          │      SQL_INJECTION / REMOTE_CODE_EXEC -> CRITICAL
          │      BRUTE_FORCE / PORT_SCAN          -> HIGH
          │      UNAUTHORIZED / RATE_LIMIT        -> MEDIUM
          │      Other                            -> LOW
          │
          ├── 5. Output CSV Emission:
          │      Record: TIMESTAMP,IP,PORT,SEVERITY,REASON,SCOPE
          │
          └── 6. Accumulate Metrics: TOTAL, CRITICAL, HIGH, MEDIUM, EXTERNAL
          │
          ▼
[ Output: CLASSIFIER_SUMMARY ]
```

---

## 6. Self-Assessment Checklist
Before you begin modifying `classifier.sh`:

1. **What is stored in `${BASH_REMATCH[0]}` versus `${BASH_REMATCH[1]}`?**
   * *Answer*: `${BASH_REMATCH[0]}` holds the entire substring matched by the regular expression. `${BASH_REMATCH[1]}` holds the first parenthesized capture group.
2. **Why should regular expressions on the right-hand side of `=~` NOT be enclosed in double quotes?**
   * *Answer*: In Bash 3.2+, quotes force the regex engine to treat all metacharacters (`*`, `+`, `^`, `$`) as literal characters.
3. **When should you choose glob matching (`[[ $ip == 10.* ]]`) over regex (`[[ $ip =~ ^10\. ]]`)?**
   * *Answer*: For simple prefix/suffix checks, glob matching is simpler and significantly faster than invoking the regex engine.
4. **How do capture groups work if multiple sets of parentheses are used?**
   * *Answer*: They are indexed left-to-right starting from 1: `${BASH_REMATCH[1]}`, `${BASH_REMATCH[2]}`, etc.
5. **How does Bash regex matching avoid the overhead of `grep` or `awk`?**
   * *Answer*: Bash calls POSIX C library regex functions directly in the running shell process, without spawning subshells or executing external binary files.

---

## 7. Mission Objectives
Implement `classifier.sh` as a real-time security threat classifier:
1. Accept input log file as `$1` (default: `firewall.log`) and output CSV file as `$2` (default: `threats.csv`).
2. Strictly no external text utilities: no `grep`, `awk`, `cut`, `sed`, `python`, `perl`.
3. Match alert lines using native regex:
   `^ALERT[[:space:]]+ts=([0-9]+)[[:space:]]+ip=([0-9.]+)[[:space:]]+port=([0-9]+)[[:space:]]+reason=([A-Z_]+)`
4. Classify threat severity:
   - `SQL_INJECTION`, `REMOTE_CODE_EXEC`: `CRITICAL`
   - `BRUTE_FORCE_AUTH`, `PORT_SCAN`: `HIGH`
   - `UNAUTHORIZED_ACCESS`, `RATE_LIMIT_EXCEEDED`: `MEDIUM`
   - All other reasons: `LOW`
5. Classify threat scope:
   - If IP starts with `10.` or `192.168.` or `172.16.`: `INTERNAL`
   - Else: `EXTERNAL`
6. Write CSV header `TIMESTAMP,IP,PORT,SEVERITY,REASON,SCOPE` and append matched records.
7. Output summary: `CLASSIFIER_SUMMARY: evaluated=<N>, threats=<T>, critical=<C>, high=<H>, medium=<M>, external=<E>`.
