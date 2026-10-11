# Structural Scaffolding: Zero-Downtime Atomic Symlink Swapping

To avoid exposing a transient `ENOENT` (file not found) state during symlink rotation, replace the naive dual-operation (`rm` followed by `ln`) with the kernel-level atomic `rename(2)` transaction.

---

## Pattern: Staged Atomic Inode Replacement

```bash
# 1. Define isolated staging path in the identical directory to avoid EXDEV errors:
STAGING_LINK="${SYMLINK_PATH}.tmp.$$"

# 2. Guarantee cleanup of orphan staging links on abnormal termination:
trap 'rm -f "$STAGING_LINK"' EXIT

# 3. Create the staging symlink pointing to the next release artifact:
ln -s "$TARGET_RELEASE" "$STAGING_LINK"

# 4. Perform the atomic dentry swap:
# -T (--no-target-directory) prevents mv from placing the staging link
# inside an existing target directory, forcing an in-place rename(2).
mv -T "$STAGING_LINK" "$SYMLINK_PATH"
```

---

## Verifying Inode Continuity Under Concurrency

To verify that the target path never ceases to exist during rotation, concurrent processes can query inode pointers continuously:

```bash
# Continuous read without error:
while true; do
    stat -c "Target Inode: %i, Path: %N" current || {
        echo "RACE CONDITION: current was missing!"
        break
    }
done
```
