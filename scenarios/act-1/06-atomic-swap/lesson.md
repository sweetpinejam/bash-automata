# Tactical Field Manual: The Atomic Swap (Zero-Downtime Releases & `mv -T`)

> **POSIX & Linux Systems Engineering Handbook**  
> **Subsystem**: Linux Virtual Filesystem Switch (VFS), Inode / Dentry Metadata, and Atomic `rename(2)`

---

## 1. Architectural Mental Model: Blue-Green Deployment & Symlinks

In zero-downtime production deployments (used by tools like Capistrano, Kubernetes volume mounts, systemd service units, and web servers like NGINX and Caddy), active traffic is served through a stable filesystem path pointing to an immutable versioned directory:

```
                  ┌──────────────────────┐
                  │ Client / Web Traffic │
                  └──────────┬───────────┘
                             │
                      /var/www/current  (Symlink)
                             │
            ┌────────────────┴────────────────┐
            ▼                                 ▼
   /var/www/releases/v1              /var/www/releases/v2
   (Active: Production)              (Staging: Prepared)
```

When switching traffic from `v1` to `v2`, the symlink `/var/www/current` must be updated.

### The Naive Antipattern: Dual-Syscall Removal Window

Many naive deployment scripts execute:
```bash
# 💥 THE DOWNTIME WINDOW:
rm -f /var/www/current
ln -s /var/www/releases/v2 /var/www/current
```

At the Linux kernel level, this sequence executes two distinct, non-atomic system calls:
1. `unlink("/var/www/current")` (or `unlinkat`) — Deletes the directory entry from the parent directory's block.
2. `symlink("/var/www/releases/v2", "/var/www/current")` — Allocates a new inode and inserts a new directory entry.

Between step 1 and step 2, there is an operating system scheduling window (often tens to hundreds of microseconds). During this window, any concurrent thread or process calling `open()`, `stat()`, or traversing the directory path receives an immediate **`ENOENT` (No such file or directory)**:

```
Thread A (Deployer)           Thread B (NGINX / FastCGI Worker)
───────────────────           ─────────────────────────────────
unlink("current")
                              open("current/index.html") ──▶ Returns ENOENT (404 Error!)
symlink("v2", "current")
```

### The False Promise of `ln -sfn`

A widespread myth is that GNU `ln -sfn` (or `ln -sf`) performs an atomic replacement. **It does not.**  
When GNU coreutils `ln` encounters `-f` on an existing destination, its C implementation does not call `rename(2)`. Instead, it internally calls `unlink(dest)` followed by `symlink(target, dest)`. The race condition window remains fully exposed to high-frequency readers.

---

## 2. Kernel Primitives & The `rename(2)` Atomic Guarantee

### How Linux Directory Entries (Dentries) Work
In the Linux VFS (Virtual Filesystem Switch), a directory is an array of directory entries (`struct linux_dirent64`) mapping file names to inode numbers (`ino_t`).

```
Parent Directory Inode
┌──────────────┬───────────────┐
│ Name (char*) │ Inode Number  │
├──────────────┼───────────────┤
│ "v1"         │ 481920        │
│ "v2"         │ 481921        │
│ "current"    │ 481930 (link) │ ──▶ Points to Inode 481920 (v1)
└──────────────┴───────────────┘
```

When you invoke the POSIX system call `rename(oldpath, newpath)` (or `renameat2(2)`):
1. The kernel locks the parent directory inode (or both parent inodes if moving across directories on the same filesystem).
2. The kernel updates the directory entry table in a single atomic transaction.
3. If `newpath` already exists, its previous link is unlinked within the **same** atomic operation.

**There is never an instant where `newpath` does not exist.** At any nanosecond during concurrent execution, an incoming reader thread opening `current` resolves to *either* the old inode or the new inode—never `ENOENT`.

---

## 3. The Two-Step Atomic Symlink Swap Idiom

Because `ln` cannot create a symlink directly over an existing destination atomically, POSIX systems use the **two-step temporary link + atomic rename** pattern:

```
Step 1: ln -s releases/v2 current.tmp.$$
        Creates staging symlink alongside the target.

Step 2: mv -T current.tmp.$$ current
        Atomically swaps the dentry in the parent directory via rename(2).
```

### Why the `-T` (`--no-target-directory`) Flag is Mandatory

In standard Unix `mv`:
```bash
mv source destination
```
If `destination` is an existing directory—or a **symlink pointing to an existing directory**—`mv` assumes you want to move `source` *into* that directory!
```bash
# DANGEROUS WITHOUT -T:
mv current.tmp current
# Moves current.tmp into releases/v1/current.tmp !
```
The **`-T` (`--no-target-directory`)** flag explicitly instructs GNU `mv`:
> *"Treat `DEST` as a normal file, never as a directory."*

With `-T`, `mv` directly issues `rename("current.tmp", "current")`, replacing the symlink pointer itself rather than traversing through it.

---

## 4. Production Constraints & Edge Cases

| Hazard | Cause | Prevention / Solution |
| :--- | :--- | :--- |
| **`EXDEV` (Invalid cross-device link)** | `current.tmp` and `current` reside on different filesystems or mount points. `rename(2)` cannot span filesystems. | Always create the temporary symlink in the **exact same parent directory** (e.g., `"${SYMLINK_PATH}.tmp.$$"`) to guarantee identical mount point. |
| **Dangling Staging Files** | Deploy script aborts or receives `SIGINT` before `mv -T` completes. | Register defensive cleanup trap: `trap 'rm -f "$TMP_LINK"' EXIT`. |
| **PID Collisions Across Hosts** | Multiple deployment agents running simultaneously. | Incorporate process ID and nanosecond timestamp: `current.tmp.$$.$(date +%s%N)`. |
| **Stale File Handles on NFS / CIFS** | Network filesystems caching old dentry attributes. | Mount with `actimeo=0` or issue explicit attribute cache invalidation if using shared network storage. |

---

## 5. Curated Reading List & Authoritative Manuals

Before completing your implementation, study these authoritative systems documentation sources:

1. **`man 2 rename` & `man 2 renameat2`**
   - The Linux Programmer's Manual on filesystem atomicity guarantees, replacement semantics, and `RENAME_EXCHANGE` / `RENAME_NOREPLACE` flags.
2. **`man 1 mv`**
   - Read the exact specifications for `-T, --no-target-directory` and `--backup=numbered`.
3. **`man 7 path_resolution`**
   - Deep kernel guide explaining how the Linux kernel resolves pathnames and traverses symbolic links (`follow_link`, `dentry` cache lookup).
4. **`man 7 inode`**
   - POSIX file metadata, hard links, symbolic links, and link count (`nlink_t`) management.
5. **POSIX IEEE Std 1003.1-2017**: Section `rename`
   - Specifications for atomic directory entry replacement behavior across POSIX-compliant kernels.
6. **The Linux Programming Interface (TLPI) by Michael Kerrisk**
   - *Chapter 18: Directories and Links* — Section 18.2 (Removing a File: `unlink()`), Section 18.3 (Renaming a File: `rename()`), and Section 18.5 (Symbolic Links).

---

## 6. Self-Assessment Checklist

Test your conceptual understanding:
- [ ] Why does `rm current && ln -s ...` cause HTTP 404 / `ENOENT` errors even if the script takes less than 1 millisecond?
- [ ] Why does `ln -sfn target link` fail to provide atomic guarantees on GNU/Linux systems?
- [ ] What is the exact role of the `-T` flag in `mv -T source dest`, and what catastrophic error occurs if it is omitted when `dest` points to a directory?
- [ ] What system error code is returned if you attempt to call `rename(2)` between two paths on different mounted filesystems (`/tmp` vs `/var/www`)?
- [ ] How does `renameat2(2)` with `RENAME_EXCHANGE` allow atomic swapping of two active directories without a temporary third name?
