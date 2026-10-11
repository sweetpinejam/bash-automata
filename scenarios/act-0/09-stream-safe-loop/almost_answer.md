# Code Blueprint: Stream-Safe Line-by-Line Reading

Never use `for line in $(cat file)` to read text lines. Use `while IFS= read -r line` with input redirection to preserve indentation, spaces, and backslashes:

```bash
# Blueprint Pattern:
while IFS= read -r line || [[ -n "$line" ]]; do
  echo "$line" >> "$output"
done < "$input"
```

> **Key Rule**:
> - `IFS=` prevents trimming leading/trailing whitespace.
> - `-r` prevents backslash escaping.
> - `|| [[ -n "$line" ]]` ensures the final line is not dropped if it lacks a trailing newline.
