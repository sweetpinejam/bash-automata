# Code Blueprint: Regex Matching & `BASH_REMATCH` Captures

Match strings with regex inside `[[ ... ]]` and access capture groups via the special array `BASH_REMATCH`:

```bash
# Blueprint Pattern:
pattern='^ALERT[[:space:]]+ip=([0-9.]+)[[:space:]]+port=([0-9]+)[[:space:]]+reason=([A-Z_]+)'

if [[ "$line" =~ $pattern ]]; then
  ip="${BASH_REMATCH[1]}"
  port="${BASH_REMATCH[2]}"
  reason="${BASH_REMATCH[3]}"
  echo "$ip,$port,$reason" >> "$output"
fi
```

> **Key Rule**: Do NOT quote the regex variable when referencing it inside `[[ $line =~ $pattern ]]`. Quotes make Bash treat it as a literal string rather than a regular expression.
