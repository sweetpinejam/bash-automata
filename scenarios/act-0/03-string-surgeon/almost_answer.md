# Code Blueprint & Almost-Answer: The String Surgeon

If you are stuck on pure in-memory string surgery in `sorter.sh`:

### 1. Stripping Directory Prefix
```bash
# Gets only the filename without calling basename
filename="${filepath##*/}"
```

### 2. Compound Extension Matching with `case`
```bash
case "$filename" in
    *.tar.gz)     ext="tar.gz"; stem="${filename%.tar.gz}" ;;
    *.tar.bz2)    ext="tar.bz2"; stem="${filename%.tar.bz2}" ;;
    *.backup.sql) ext="backup.sql"; stem="${filename%.backup.sql}" ;;
    *.*)          ext="${filename##*.}"; stem="${filename%.*}" ;;
    *)            ext="none"; stem="$filename" ;;
esac
```

### 3. Category Routing
```bash
case "$ext" in
    tar.gz|tar.bz2|tar.xz|zip|gz) category="archives" ;;
    json|yaml|yml|toml|conf)      category="configs" ;;
    sql|backup.sql)               category="databases" ;;
    bin|sh|none)                  category="binaries" ;;
    *)                            category="miscellaneous" ;;
esac
```

### 4. Writing Catalog & Moving File
```bash
mkdir -p "$OUTPUT_DIR/$category"
mv "$filepath" "$OUTPUT_DIR/$category/$filename"
printf "%s\t%s\t%s\t%s\n" "$filename" "$category" "$stem" "$ext" >> "$OUTPUT_DIR/catalog.tsv"
```
