# Tactical Field Manual: The Space Landmine (Word Splitting & Path Defense)

## 1. Systems Mental Model: The Bash Evaluation Pipeline
To master shell programming, you must abandon the assumption that Bash evaluates code like Python, C, or Go. In conventional languages, a string variable is an immutable or atomic object passed directly to system calls. In Bash, the shell is a **string pre-processor and pipeline orchestrator**.

Every command line undergoes a strict multi-phase expansion sequence before the Linux kernel's `execve(2)` system call is ever invoked:

```
[ Raw Command Input ]
         │
         ▼
 1. Brace Expansion ({a,b})
         │
         ▼
 2. Tilde Expansion (~/dir)
         │
         ▼
 3. Parameter & Variable Expansion ($VAR, ${VAR:-default})
         │
         ▼
 4. Command Substitution ($(cmd), `cmd`)
         │
         ▼
 5. Arithmetic Expansion ($((x + y)))
         │
         ▼
 6. WORD SPLITTING  <─── [ THE DANGER ZONE ]
    (Unquoted expansions are broken into separate argv tokens by $IFS)
         │
         ▼
 7. Pathname / Glob Expansion (*.log, deploy/*)
         │
         ▼
 8. Quote Removal (Stripping unquoted "" and '')
         │
         ▼
[ Kernel execve(argv[0], argv[1], ...) ]
```

### Why Word Splitting Occurs
During Step 6, Bash scans the results of parameter expansions, command substitutions, and arithmetic expansions for the characters defined in the **Internal Field Separator (`IFS`)** environment variable. By default:
```bash
IFS=$' \t\n'  # Space, Tab, Newline
```

If a variable expansion is **not enclosed in double quotes**, Bash treats every whitespace character inside the value as an argument separator:
```bash
# Given:
FILE="daily backup log.txt"

# When executing:
rm $FILE

# Bash expands step 3:
rm daily backup log.txt

# Bash executes step 6 (Word Splitting):
argv[0] = "rm"
argv[1] = "daily"
argv[2] = "backup"
argv[3] = "log.txt"

# Kernel executes: rm("daily", "backup", "log.txt") -> 3 distinct files!
```

---

## 2. The Quoting Matrix: What Quotes Actually Do

Understanding Bash quoting requires distinguishing between **literal preservation**, **expansion suppression**, and **boundary encapsulation**:

| Syntax | Expands `$VAR`? | Expands Globs `*`? | Preserves Whitespace? | Primary Use Case |
| :--- | :---: | :---: | :---: | :--- |
| `"$VAR"` | **YES** | **NO** | **YES** | Safe variable expansion (Everyday gold standard) |
| `'$VAR'` | **NO** (Literal) | **NO** | **YES** | Hard strings, regex patterns, raw formatting |
| `"$DIR"/*` | **YES** | **YES** | **YES** | Safe directory traversal with globbing |
| `"$DIR/*"` | **YES** | **NO** (Literal `*`) | **YES** | ❌ BROKEN: Looks for a literal file named `*` |
| `$VAR` | **YES** | **YES** | **NO** (Splits!) | ❌ DANGEROUS: Suffers word splitting and globbing |

### The Rule of Wildcard Placement
When globbing inside a directory that may contain spaces:
```bash
# ✅ CORRECT: The path is quoted; the wildcard operator is outside quotes:
for file in "$TARGET_DIR"/*; do
  ...
done

# ❌ INCORRECT: The asterisk is quoted and treated literally:
for file in "$TARGET_DIR/*"; do  # Fails unless a file named '*' literally exists
  ...
done
```

---

## 3. Real-World Disaster Stories: The Unquoted Variable CVEs

The danger of unquoted variables is not theoretical. Unquoted path expansions have caused some of the most infamous production outages in software history:

### 1. The Valve Steam Linux Client Incident (`rm -rf "$STEAMROOT/"*`)
In a release script for the Steam Linux client, developers wrote:
```bash
STEAMROOT="$HOME/.local/share/Steam"
# Under certain initialization conditions, STEAMROOT was empty ("")!
rm -rf "$STEAMROOT/"*
```
Because `STEAMROOT` was empty, `"$STEAMROOT/"*` expanded to `"/"*`, recursively destroying the entire root filesystem of every user who ran the update.

### 2. The Knight Capital / Staging Sweep Flaw
```bash
STAGE_DIR="release build/artifacts"
# Unquoted command:
rm -rf $STAGE_DIR
# Expanded to:
rm -rf release build/artifacts
# Deleted the production 'release' directory instead of 'release build/artifacts'!
```

---

## 4. Traversal Patterns: Handling Arbitrary Whitespace & Newlines

When writing real automation utilities that traverse files, three traditional Bash patterns exist:

### Pattern A: Quoted Glob Iteration (Simple, Fast, Safe)
```bash
# Nullglob ensures the loop does not execute if the directory is empty
shopt -s nullglob
for item in "$SOURCE_DIR"/*; do
    [[ -e "$item" ]] || continue  # Guard against empty directories
    echo "Found item: $item"
done
shopt -u nullglob
```

### Pattern B: Recursive Find with NUL-Delimited Streams (Zero-Failure)
Filenames on POSIX filesystems can contain spaces, tabs, and even literal newlines (`\n`). The only two characters forbidden in a POSIX filename are `/` (path separator) and `\0` (NUL byte).
```bash
# -print0 terminates every output path with a NUL byte (\0)
# IFS= read -r -d '' reads up to the NUL byte without trimming spaces
while IFS= read -r -d '' filepath; do
    echo "Processing: $filepath"
    size=$(wc -c < "$filepath")
done < <(find "$SOURCE_DIR" -type f -print0)
```

---

## 5. Architectural Diagram: Safe Argument & Stream Flow

```
[ CLI Invocation: ./cleaner.sh --dry-run "deploy artifacts" "archived runs" ]
                                  │
                                  ▼
                     [ Flag Parsing & Validation ]
                     - Detect --dry-run (shift)
                     - Assert $# == 2
                     - Check [[ -d "$SRC" ]]
                                  │
                                  ▼
                     [ Whitespace-Safe Scanner ]
               find "$SRC" -type f -print0  (NUL-delimited)
                                  │
                                  ▼
               while IFS= read -r -d '' filepath
               ├── File Size: stat/wc on "$filepath"
               ├── Accumulate: COUNT++, TOTAL_BYTES += size
               ├── If DRY_RUN: print "[DRY_RUN] Would move..."
               └── If LIVE:
                   ├── mkdir -p "$(dirname "$dest_path")"
                   ├── mv "$filepath" "$dest_path"
                   └── Record to "$DEST/manifest.tsv"
                                  │
                                  ▼
                 [ Output SWEEP_COMPLETE Summary ]
```

---

## 6. Self-Assessment Checklist
Before you begin modifying `cleaner.sh`, ensure you can answer every question:

1. **Why does `rm -rf $DIR` delete multiple targets if `DIR="cache temp"`?**
   * *Answer*: Because Bash performs Word Splitting on unquoted expansions, passing `"cache"` and `"temp"` as separate arguments to `rm`.
2. **Why does `for f in $(ls "$DIR")` fail catastrophically on files with spaces?**
   * *Answer*: `$(ls "$DIR")` emits a string of filenames separated by newlines and spaces. Word splitting breaks single filenames with spaces into multiple tokens.
3. **What is the difference between `"$DIR"/*` and `"$DIR/*"`?**
   * *Answer*: In `"$DIR"/*`, the wildcard `*` is unquoted and triggers Pathname Expansion. In `"$DIR/*"`, the asterisk is quoted and treated as a literal character.
4. **Why is `find ... -print0` combined with `read -r -d ''` the POSIX gold standard for file processing?**
   * *Answer*: The NUL byte (`\0`) is the only character that cannot exist in a filename. Using it as a delimiter prevents splitting on spaces, tabs, and newlines.
5. **Why should you always test both `--dry-run` and live execution in cleanup automation?**
   * *Answer*: Destructive operations must allow safe pre-flight verification to prevent accidental data loss in production.

---

## 7. Mission Objectives
Refactor `cleaner.sh` into a complete, resilient automation utility:
1. Support optional `--dry-run` flag as first argument.
2. Validate that source and destination arguments are provided and source directory exists.
3. Traverse all files inside the source directory safely, regardless of spaces in directory or file names.
4. Calculate total file count and total byte size.
5. In dry-run mode, print `[DRY_RUN] Would move: <source> -> <dest>` and leave files intact.
6. In live mode, move files to the destination and record entries in `manifest.tsv`.
7. Output completion summary: `SWEEP_COMPLETE: files=<COUNT>, bytes=<TOTAL_BYTES>, dry_run=<0|1>`.
