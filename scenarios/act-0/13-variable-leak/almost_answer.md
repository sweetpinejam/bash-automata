# Code Blueprint & Almost-Answer: The Variable Leak

If you need function scoping templates for `backup_bot.sh`:

### 1. Declaring `local` Scoping in Functions
```bash
process_day_chunks() {
    local day="$1"
    local chunk_id

    for chunk_id in 1 2 3; do
        :
    done
}

archive_day() {
    local day="$1"
    local chunks_count=3

    process_day_chunks "$day"
    printf "DAY_%d\t%d\tSUCCESS\n" "$day" "$chunks_count" >> "$MANIFEST_FILE"
}
```

### 2. Main Orchestration Loop
```bash
day_id=1
while (( day_id <= TOTAL_DAYS )); do
    archive_day "$day_id"
    (( TOTAL_CHUNKS += 3 ))
    (( ++day_id ))
done
```
