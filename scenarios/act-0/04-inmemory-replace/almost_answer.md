# Code Blueprint & Almost-Answer: Pure In-Memory Replace

If you need structural syntax guidance to complete `sanitizer.sh`:

### 1. In-Memory Replacements Inside the Stream Loop
```bash
while IFS= read -r line || [[ -n "$line" ]]; do
    TOTAL_LINES=$((TOTAL_LINES + 1))
    original="$line"

    # Prefix replacement
    line="${line/#DEBUG:/[TRACE]:}"

    # Global replacements
    line="${line//dev.internal/prod.external}"
    line="${line//SECRET_/REDACTED_}"

    # Suffix scrubbing (escape question mark)
    line="${line/%\?session=*/}"

    if [[ "$line" != "$original" ]]; then
        MODIFIED_LINES=$((MODIFIED_LINES + 1))
    fi

    echo "$line" >> "$OUTPUT_FILE"
done < "$INPUT_FILE"
```

### 2. Generating Audit JSON
```bash
cat <<EOF > "audit_metrics.json"
{
  "status": "SANITIZED",
  "total_lines": $TOTAL_LINES,
  "lines_modified": $MODIFIED_LINES,
  "engine": "bash_in_memory"
}
EOF
```
