# Code Blueprint & Almost-Answer: The Space Landmine

If you are stuck, use this structured architectural skeleton to complete `cleaner.sh`:

### 1. Flag and Positional Argument Parsing
```bash
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 [--dry-run] <src> <dest>" >&2
    exit 1
fi

SRC_DIR="$1"
DEST_DIR="$2"

if [[ ! -d "$SRC_DIR" ]]; then
    exit 1
fi
```

### 2. Destination Directory & Manifest Initialization
```bash
if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$DEST_DIR"
    : > "$DEST_DIR/manifest.tsv"
fi
```

### 3. Whitespace-Safe File Scanning & Manifest Recording
```bash
while IFS= read -r -d '' file; do
    [[ -f "$file" ]] || continue

    bytes=$(wc -c < "$file")
    TOTAL_BYTES=$((TOTAL_BYTES + bytes))
    TOTAL_FILES=$((TOTAL_FILES + 1))

    filename="${file##*/}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[DRY_RUN] Would move: $file -> $DEST_DIR/$filename"
    else
        mv "$file" "$DEST_DIR/$filename"
        printf "%s\t%d\n" "$filename" "$bytes" >> "$DEST_DIR/manifest.tsv"
    fi
done < <(find "$SRC_DIR" -type f -print0)
```
