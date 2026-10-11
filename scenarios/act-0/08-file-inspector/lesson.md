# Tactical Field Manual: The File Inspector (POSIX Filesystem & Inode Auditing)

## 1. Systems Mental Model: How Linux Tests Files (The `stat(2)` Syscall)
When you write `[[ -f "$file" ]]` or `[[ -x "$bin" ]]` in Bash, what actually happens inside the Linux kernel?

The shell issues a `stat(2)` or `lstat(2)` system call to query the file's **inode metadata table** stored in filesystem blocks:

```
[ Path: "bin/app" ]
        │
        ▼
   stat("bin/app", &statbuf)
        │
        ▼
   statbuf:
   ├── st_mode: S_IFREG | 0755  (File type: Regular file, Permissions: rwxr-xr-x)
   ├── st_size: 482910 bytes    (File size in bytes)
   ├── st_uid / st_gid: 1000    (Owner and group)
   └── st_mtime: 1700000000     (Modification timestamp)
```

Bash inspects the bits in `statbuf.st_mode` directly in memory:
* `[[ -f "$file" ]]` checks the `S_ISREG()` macro.
* `[[ -d "$dir" ]]` checks the `S_ISDIR()` macro.
* `[[ -s "$file" ]]` checks `statbuf.st_size > 0`.
* `[[ -x "$file" ]]` checks executable permission bits against the running process's effective UID/GID.

---

## 2. Complete Taxonomy of File Test Operators

Mastering deployment automation requires knowing the full spectrum of POSIX file test operators:

| Operator | Evaluates True If... | Systems Context / Common Use Case |
| :--- | :--- | :--- |
| **`-e`** | Path exists (any file type) | Baseline existence check |
| **`-f`** | Path exists and is a **regular file** | Config files, binaries, archives |
| **`-d`** | Path exists and is a **directory** | Working directories, log folders |
| **`-s`** | Path exists and has **size > 0 bytes** | Detecting empty/corrupted config files |
| **`-r`** | Path exists and is **readable** by process | Verifying read access before open |
| **`-w`** | Path exists and is **writable** by process | Verifying spool/scratch write access |
| **`-x`** | Path exists and is **executable** | Verifying binaries and hook scripts |
| **`-L` / `-h`** | Path exists and is a **symbolic link** | Blue-green deployment pointer checks |
| **`-S`** | Path exists and is a **Unix domain socket** | IPC daemon daemon listener health |
| **`-p`** | Path exists and is a **named pipe (FIFO)** | Stream buffer pipeline health |
| **`-nt`** | File A is **newer than** File B (mtime) | Build artifact cache invalidation |
| **`-ot`** | File A is **older than** File B (mtime) | Garbage collection of stale runs |
| **`-ef`** | File A and B share the **same inode** | Hardlink verification |

---

## 3. The Dangling Symlink Trap (`-L` vs `-e`)

The most common trap in blue-green deployments (symlink-based version switching) is the **dangling symlink**:
```bash
# Given a symlink pointing to a missing directory:
ln -s "/releases/v2_deleted" current_release

# What happens when we test it?
if [[ -L current_release ]]; then
    echo "Symlink exists!"   # PRINTS THIS! The symlink pointer itself exists!
fi

if [[ -e current_release ]]; then
    echo "Target exists!"    # FAILS! -e follows the symlink to the non-existent target!
fi
```

### The Broken Symlink Detection Idiom:
To verify that a symlink is **healthy and not dangling**:
```bash
if [[ -L "$link" ]]; then
    if [[ ! -e "$link" ]]; then
        echo "ERROR: Dangling symlink detected: $link points to missing target!"
        exit 1
    fi
fi
```
* `-L "$link"` uses `lstat(2)`: tests the symlink node itself without following it.
* `-e "$link"` uses `stat(2)`: traverses the link to test whether the target entity actually exists on disk.

---

## 4. Architectural Diagram: Pre-Flight Health Auditor

```
[ CLI: ./preflight.sh --report health_report.json ]
                         │
                         ▼
           [ Check 1: Config File Integrity ]
    [[ -f "config/app.conf" && -s "config/app.conf" && -r "config/app.conf" ]]
                         │
                         ▼
           [ Check 2: Release Directory Writable ]
    [[ -d "releases" && -w "releases" ]]
                         │
                         ▼
           [ Check 3: Binary Executable Check ]
    [[ -f "bin/app" && -x "bin/app" ]]
                         │
                         ▼
           [ Check 4: Symlink Health (No Dangling) ]
    [[ -L "current_release" ]] && [[ -e "current_release" ]]
                         │
                         ▼
           [ Check 5: Logs Directory Writable ]
    [[ -d "logs" && -w "logs" ]]
                         │
                         ▼
           [ Emission & JSON Report ]
    Record PASS/FAIL status per check
    Generate health_report.json
    Exit 0 (ALL_CHECKS_PASSED) or Exit 1 (PREFLIGHT_FAILED)
```

---

## 5. Self-Assessment Checklist
Before modifying `preflight.sh`:

1. **Why does `[[ -f "$file" ]]` return false on an empty directory or symlink to a directory?**
   * *Answer*: Because directories and directory symlinks are not regular files (`S_IFREG`).
2. **What does `[[ -s "$file" ]]` test?**
   * *Answer*: It tests whether the file exists and has a byte size strictly greater than zero (`st_size > 0`).
3. **Why does `[[ -L "$link" ]]` return true even if the target file was deleted?**
   * *Answer*: `-L` queries `lstat(2)` on the link inode itself. The link pointer exists even if its target does not.
4. **How do you verify that a symlink points to a valid, existing target?**
   * *Answer*: By testing `[[ -L "$link" && -e "$link" ]]`.
5. **What is the difference between `-e` and `-f`?**
   * *Answer*: `-e` tests if any entity exists at the path (sockets, FIFOs, directories, symlinks, device files). `-f` tests specifically for regular files.

---

## 6. Mission Objectives
Implement `preflight.sh` as a production pre-flight filesystem auditor:
1. Accept optional `--report <file>` (default: `health_report.json`).
2. Run five distinct filesystem health checks:
   - **Check 1 (`config_integrity`)**: `config/app.conf` must exist (`-f`), have non-zero size (`-s`), and be readable (`-r`).
   - **Check 2 (`release_dir_writable`)**: `releases/` must exist (`-d`) and be writable by current user (`-w`).
   - **Check 3 (`binary_executable`)**: `bin/app` must exist (`-f`) and have execute permissions (`-x`).
   - **Check 4 (`symlink_integrity`)**: `current_release` must be a symlink (`-L`) and its target must exist (`-e`).
   - **Check 5 (`logs_dir_writable`)**: `logs/` must exist (`-d`) and be writable (`-w`).
3. Print informative progress for each check: `[PASS] <description>` or `[FAIL] <reason>`.
4. Generate structured `health_report.json` with overall status (`PASSED` or `FAILED`), total checks, and individual check statuses.
5. Exit codes:
   - If all checks pass: print `ALL_CHECKS_PASSED` and exit 0.
   - If any check fails: print `PREFLIGHT_FAILED: <failed_check>` and exit 1.
