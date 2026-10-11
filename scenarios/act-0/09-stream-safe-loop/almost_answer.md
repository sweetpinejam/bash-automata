# Code Blueprint & Almost-Answer: Stream-Safe While Loops

If you need structural loop templates for `compiler.sh`:

### 1. The Stream-Safe While Loop
```bash
while IFS= read -r line || [[ -n "$line" ]]; do
    (( ++TOTAL_LINES ))

    # 1. Skip comments if flag is set
    if (( STRIP_COMMENTS == 1 )) && [[ "$line" =~ ^[[:space:]]*# ]]; then
        (( ++STRIPPED_LINES ))
        continue
    fi

    # 2. In-memory substitutions
    for key in "${!VARS[@]}"; do
        placeholder="{{$key}}"
        if [[ "$line" == *"$placeholder"* ]]; then
            val="${VARS[$key]}"
            line="${line//$placeholder/$val}"
            (( ++SUBSTITUTED_COUNT ))
        fi
    done

    # 3. Output rendered line
    echo "$line" >> "$OUTPUT_FILE"
    (( ++WRITTEN_LINES ))
done < "$TEMPLATE_FILE"
```
