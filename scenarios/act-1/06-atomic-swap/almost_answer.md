# Code Blueprint: Zero-Downtime Atomic Symlink Swapping

Never run `rm -f current && ln -s ... current`. The deletion step creates a race window where the path doesn't exist. Instead, leverage atomic `renameat2` via `mv -T`:

```bash
# Blueprint Pattern:
TMP_LINK="current.tmp.$$"

# Create a temporary symlink pointing to the new target:
ln -s "$TARGET_RELEASE" "$TMP_LINK"

# Atomically replace destination symlink with rename:
mv -T "$TMP_LINK" current
```

> **Key Rule**: The `-T` (`--no-target-directory`) flag treats `current` strictly as a file/link rather than a directory, causing `mv` to invoke the atomic POSIX `rename()` syscall.
