# Tactical Field Manual: Pattern & Regex Matching (`=~` and `BASH_REMATCH`)

## 1. The Mental Model (Built-in POSIX Extended Regular Expressions)
Most programmers think Bash can only do string equality (`==`) and that extracting regex groups requires invoking `grep -P`, `sed`, or `awk`.

Starting in Bash 3.0, the compound test keyword `[[ ... ]]` includes the **`=~`** regular expression operator.
When an expression matches:
1. The return status is `0` (true).
2. Bash automatically populates an internal array named **`BASH_REMATCH`**:
   - `${BASH_REMATCH[0]}`: The complete text that matched the pattern.
   - `${BASH_REMATCH[1]}`: The substring captured by the **1st** parenthesis group `(...)`.
   - `${BASH_REMATCH[2]}`: The substring captured by the **2nd** parenthesis group `(...)`.

---

## 2. Syntax Cheatsheet: Regex Matching & Capturing

```bash
# 1. Best practice: Store complex regex patterns in a variable (avoids escaping issues)
pattern='^ALERT[[:space:]]+ip=([0-9.]+)[[:space:]]+port=([0-9]+)'

line="ALERT ip=192.168.1.50 port=443 reason=TIMEOUT"

if [[ "$line" =~ $pattern ]]; then
    echo "Full match:  ${BASH_REMATCH[0]}"
    echo "Captured IP:   ${BASH_REMATCH[1]}"
    echo "Captured Port: ${BASH_REMATCH[2]}"
fi

# 2. Glob pattern matching (no regex):
# Use == with glob wildcards (unquoted wildcards!)
if [[ "$line" == ALERT* ]]; then
    echo "Line starts with ALERT"
fi
```

---

## 3. Deadly Pitfall: Quoting the Regex Pattern
In Bash, if you put quotes around the pattern on the right side of `=~`, Bash treats the pattern as a **literal string**, not a regular expression!
```bash
# ❌ WRONG: Bash searches for literal characters "[0-9]+" instead of matching digits!
if [[ "$IP" =~ "^[0-9]+$" ]]; then ... fi

# ✅ RIGHT (unquoted pattern on right, or stored in variable):
regex='^[0-9]+$'
if [[ "$IP" =~ $regex ]]; then ... fi
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `=~` and `BASH_REMATCH`)
* Greg's Bash Wiki: [BashFAQ/035: How to use regular expressions in Bash](https://mywiki.wooledge.org/BashFAQ/035)
* ShellCheck Wiki: Rule `SC2076` (Don't quote rhs of =~ if you intend regex matching)

---

## 5. Mission Objective
Edit `classifier.sh` in your sandbox. Use `[[ "$line" =~ $pattern ]]` and extract `${BASH_REMATCH[1]}`, `${BASH_REMATCH[2]}`, and `${BASH_REMATCH[3]}` to filter and format alerts into `threats.csv` without spawning external tools.
