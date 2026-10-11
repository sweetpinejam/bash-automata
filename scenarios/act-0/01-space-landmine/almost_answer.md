# Code Blueprint: Defensive Quoting & Path Globbing

When passing variable expansions containing spaces to utilities like `mkdir` and `mv`, wrap the variable expansion in double quotes. When expanding wildcards, keep the wildcard glob character outside the quotes so the shell expands it.

```bash
# Blueprint Pattern:
mkdir -p "$TARGET_DIR"
mv "$SOURCE_DIR"/* "$DEST_DIR"/
```

> **Key Rule**: Variable inside quotes (`"$DIR"`), wildcard outside quotes (`/*`).
