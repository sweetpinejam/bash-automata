# Tactical Field Manual: The Bracket Duel (`[` vs `[[ ]]`)

## 1. The Mental Model (Why Single Brackets Crash)
In early Unix, `[` was not a shell keyword. It was an actual executable binary: `/bin/test` (aliased as `/bin/[`).
Because it is a regular command, everything passed into `[` is subject to normal shell evaluation: **word splitting** and **glob expansion**.

```bash
TARGET=""
if [ $TARGET = "prod" ]; then   # Expands to: [ = "prod" ]
```
Because `$TARGET` expands to nothing, the `[` command receives only two arguments: `=` and `"prod"`. It throws:
`bash: [: =: unary operator expected`!

Similarly, if `$TARGET="prod cluster"`, it expands to:
`[ prod cluster = "prod" ]`
The `[` command receives 4 arguments and crashes with:
`bash: [: too many arguments`!

---

## 2. The Solution: Modern Compound Test `[[ ... ]]`
Bash introduced the keyword `[[ ... ]]`.
Because it is a shell syntax construct (not a command):
1. **No Word Splitting**: Unquoted variables inside `[[ ... ]]` do not split into multiple arguments. Empty variables do not vanish.
2. **Native Logical Operators**: Use `&&` and `||` directly instead of fragile `-a` and `-o`.
3. **Pattern and Regex Matching**: Enables glob matching (`== *.log`) and regex (`=~ ^[0-9]+$`).

---

## 3. Comparison Matrix

| Feature | Legacy `[ ... ]` (`test`) | Modern `[[ ... ]]` |
| :--- | :--- | :--- |
| **Word Splitting** | Yes (crashes if unquoted) | No (safe even unquoted) |
| **Empty Strings** | Crashes unless quoted `"$VAR"` | Safe |
| **Logical AND** | `-a` (fragile, deprecated) | `&&` (native) |
| **Logical OR** | `-o` (fragile, deprecated) | `\|\|` (native) |
| **Glob Matching** | No | `[[ $VAR == pattern* ]]` |
| **Regex Matching** | No | `[[ $VAR =~ ^pattern$ ]]` |

---

## 4. Syntax Cheatsheet: Common Patterns
```bash
# ✅ Robust string checks
if [[ -z "$VAR" ]]; then
    echo "Variable is empty"
fi

if [[ "$VAR" == "production" && "$TIER" == "critical" ]]; then
    echo "High risk operation"
fi

if [[ "$ENV" == "staging" || "$ENV" == "dev" ]]; then
    echo "Non-production environment"
fi
```

---

## 5. Recommended Reading List
* `man 1 bash` (Search for: `[[ expression ]]`)
* Greg's Bash Wiki: [Tests and Conditionals](https://mywiki.wooledge.org/BashFAQ/031)
* ShellCheck Wiki: Rule `SC2235` (Use `[[ ... ]]` instead of `[ ... ]`)

---

## 6. Mission Objective
Edit `validator.sh` in your sandbox. Modernize all conditional statements from single `[` to compound `[[ ]]` and replace `-a` / `-o` with `&&` / `||`.
Verify your fix with `[4] Run State Verification`.
