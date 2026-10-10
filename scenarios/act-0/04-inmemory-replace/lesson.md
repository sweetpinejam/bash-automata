# Tactical Field Manual: Pure In-Memory Replace

## 1. The Mental Model (Parameter Pattern Replacement)
Many engineers reflexively reach for `sed 's/old/new/g'` whenever they need to replace substrings.
While `sed` is a powerful stream editor for massive multi-gigabyte files, spawning `echo "$line" | sed ...` inside a shell loop can slow down execution by **100x** because of process creation overhead.

Bash provides native, in-memory **Pattern Replacement** operators:

```
               Single Match                      Global Match (All)
       ┌──────────────────────────────┐    ┌──────────────────────────────┐
       │   ${VAR/pattern/replacement} │    │  ${VAR//pattern/replacement} │
       └──────────────────────────────┘    └──────────────────────────────┘
```

---

## 2. Syntax Cheatsheet: Replacement Patterns

```bash
TEXT="https://api.staging.internal/v1/auth/token"

# 1. Replace the FIRST occurrence:
echo "${TEXT/staging/prod}"
# Output: https://api.prod.internal/v1/auth/token

# 2. Replace ALL occurrences (note the double slash //):
CONF="env=dev;tier=dev;db=dev"
echo "${CONF//dev/prod}"
# Output: env=prod;tier=prod;db=prod

# 3. Delete pattern matches (omit the replacement part):
DIRTY="[ERR] [ALERT] System rebooting"
echo "${DIRTY//\[*\] /}"
# Output: System rebooting

# 4. Anchor to Start (#) or End (%):
echo "${TEXT/#https/http}"   # Only matches if https is at the beginning
echo "${TEXT/%token/session}" # Only matches if token is at the end
```

---

## 3. Deadly Pitfall in Automated Sanitization
When replacing patterns containing slashes (e.g. URLs or file paths), you must escape the slashes with backslashes so Bash knows they are literal slashes, or assign the pattern to a variable:
```bash
URL="http://old.com/api"
# ❌ SYNTAX ERROR: extra unescaped slashes confuse Bash
# echo "${URL//http://old.com/https://new.com}"

# ✅ ESCAPED:
echo "${URL//http:\/\/old.com/https:\/\/new.com}"
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `parameter/pattern/string`)
* Greg's Bash Wiki: [ParameterExpansion#Pattern_substitution](https://mywiki.wooledge.org/ParameterExpansion#Pattern_substitution)
* Advanced Bash-Scripting Guide: Chapter 10 (Manipulating Strings)

---

## 5. Mission Objective
Edit `sanitizer.sh` in your sandbox. Use `${line//dev.internal/prod.external}` and `${sanitized//SECRET_/REDACTED_}` to sanitize `events.raw` into `events.sanitized` in-memory with zero calls to `sed`.
