# Code Blueprint & Almost-Answer: Pattern Matching in `[[ ]]`

If you need structural regex guidance for `classifier.sh`:

### 1. Regex Pattern Matching and Extraction
```bash
pattern='^ALERT[[:space:]]+ts=([0-9]+)[[:space:]]+ip=([0-9.]+)[[:space:]]+port=([0-9]+)[[:space:]]+reason=([A-Z_]+)'

if [[ "$line" =~ $pattern ]]; then
    ts="${BASH_REMATCH[1]}"
    ip="${BASH_REMATCH[2]}"
    port="${BASH_REMATCH[3]}"
    reason="${BASH_REMATCH[4]}"
    ...
```

### 2. Severity Routing with `case`
```bash
case "$reason" in
    SQL_INJECTION|REMOTE_CODE_EXEC)
        severity="CRITICAL"
        (( ++CRITICAL_COUNT ))
        ;;
    BRUTE_FORCE_AUTH|PORT_SCAN)
        severity="HIGH"
        (( ++HIGH_COUNT ))
        ;;
    UNAUTHORIZED_ACCESS|RATE_LIMIT_EXCEEDED)
        severity="MEDIUM"
        (( ++MEDIUM_COUNT ))
        ;;
    *)
        severity="LOW"
        ;;
esac
```

### 3. Scope Classification with Globs
```bash
if [[ "$ip" == 10.* || "$ip" == 192.168.* || "$ip" == 172.16.* ]]; then
    scope="INTERNAL"
else
    scope="EXTERNAL"
    (( ++EXTERNAL_COUNT ))
fi

echo "$ts,$ip,$port,$severity,$reason,$scope" >> "$OUTPUT_CSV"
```
