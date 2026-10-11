# Code Blueprint: In-Memory Prefix & Suffix Stripping

Use Bash native prefix and suffix pattern removal operators instead of slow subshells (`basename`, `cut`, `sed`):

```bash
# Blueprint Pattern:
# Strip longest matching prefix (strips directory path up to the last '/'):
filename="${filepath##*/}"

# Strip longest matching prefix up to the last dot (gets the final extension):
ext="${filename##*.}"

# Note: If there is no dot in the filename, ext will equal filename,
# or you can test: [[ "$filename" == *.* ]]
```

> **Key Rule**:
> - `#` = strip shortest prefix, `##` = strip longest prefix
> - `%` = strip shortest suffix, `%%` = strip longest suffix
