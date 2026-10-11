# Tactical Field Manual: The String Surgeon (Pure In-Memory String Surgery)

## 1. Systems Mental Model: The Kernel Overhead of Subprocess Spawning
In traditional scripts, developers frequently write:
```bash
for file in incoming/*; do
    base=$(basename "$file")
    dir=$(dirname "$file")
    ext=$(echo "$base" | cut -d. -f2)
    stem=$(echo "$base" | sed 's/\.[^.]*$//')
    ...
done
```
This looks harmless in small demos. In production automation, it is an **engineering disaster**.

### What Happens During `$(basename "$file")`?
Every time `$()` is evaluated:
1. The shell calls `fork(2)` (or `clone(2)`), duplicating the entire shell memory space and process page tables.
2. The child process opens a pipe `pipe(2)` to communicate stdout back to the parent.
3. The child calls `execve(2)` to locate `/usr/bin/basename` on disk.
4. The Linux kernel loads the ELF executable binary, maps memory pages, and invokes the dynamic linker (`ld-linux.so`).
5. The C runtime initializes, links libc, parses standard input/arguments, prints 20 bytes to stdout, and exits.
6. The kernel destroys the process context and triggers a context switch back to the parent shell.
7. The parent shell calls `wait4(2)` to reap the dead child process.

On Linux, each subprocess spawn takes **1.5 to 4 milliseconds**.
If your pipeline processes 1,000 files with 4 subprocess calls each (`basename`, `dirname`, `cut`, `sed`):
$$1,000 \times 4 \times 3\text{ ms} = 12,000\text{ ms} = 12\text{ seconds of pure CPU fork thrashing!}$$

### The Pure Bash Solution ($O(1)$ Kernel Overhead)
POSIX Bash has built-in, native string surgery operators that run directly inside the running process's CPU cache without touching the kernel, creating zero subshells and zero context switches:
$$1,000 \text{ files in-memory} = 8\text{ milliseconds total! (Over 1,000x faster)}$$

---

## 2. Syntax Anatomy: The 4 Trimming Operators

Bash provides four parameter expansion trimming operators based on whether you are cutting from the **beginning (Prefix / `#`)** or the **end (Suffix / `%`)**:

```
           [ S T R I N G ]
          ▲               ▲
          │               │
      # / ##            % / %%
     (Prefix)          (Suffix)
```

| Operator | Direction | Match Length | Mnemonic | Example (`PATH="/var/log/app.log"`) | Result |
| :--- | :---: | :---: | :--- | :--- | :--- |
| `${VAR#pattern}` | Prefix | **Shortest** | `#` is near top-left of keyboard | `${PATH#*/}` | `var/log/app.log` |
| `${VAR##pattern}` | Prefix | **Longest** | `##` cuts as much prefix as possible | `${PATH##*/}` | `app.log` (Basename!) |
| `${VAR%pattern}` | Suffix | **Shortest** | `%` is near top-right of keyboard | `${PATH%.*}` | `/var/log/app` (Stem!) |
| `${VAR%%pattern}` | Suffix | **Longest** | `%%` cuts as much suffix as possible | `${PATH%%/*}` | `""` (Empty) |

---

## 3. String Surgery Master Patterns

### 1. Extracting Directory Path (`dirname`)
Strip the shortest suffix matching `/` followed by anything:
```bash
filepath="/opt/deploy/releases/v1/server.tar.gz"
dir="${filepath%/*}"
echo "$dir"  # Output: /opt/deploy/releases/v1
```

### 2. Extracting Filename (`basename`)
Strip the longest prefix matching anything ending in `/`:
```bash
filename="${filepath##*/}"
echo "$filename"  # Output: server.tar.gz
```

### 3. Extracting Standard Extension
Strip the longest prefix matching anything up to the last dot `.`:
```bash
ext="${filename##*.}"
echo "$ext"  # Output: gz
```

### 4. Handling Compound Extensions (`.tar.gz`, `.backup.sql`)
Standard `${filename##*.}` only captures the final extension (`gz`). In production, you often need the full compound archive extension:
```bash
case "$filename" in
    *.tar.gz)   ext="tar.gz"   ; stem="${filename%.tar.gz}" ;;
    *.tar.bz2)  ext="tar.bz2"  ; stem="${filename%.tar.bz2}" ;;
    *.tar.xz)   ext="tar.xz"   ; stem="${filename%.tar.xz}" ;;
    *.backup.sql) ext="backup.sql"; stem="${filename%.backup.sql}" ;;
    *.*)        ext="${filename##*.}" ; stem="${filename%.*}" ;;
    *)          ext="none"     ; stem="$filename" ;;
esac
```

---

## 4. Architectural Diagram: In-Memory Sorting & Indexing

```
[ Incoming File: /var/tmp/incoming/api-gateway.v2.tar.gz ]
                         │
                         ▼
           [ Pure Memory Deconstruction ]
   dir="${filepath%/*}"           -> /var/tmp/incoming
   filename="${filepath##*/}"     -> api-gateway.v2.tar.gz
                         │
                         ▼
           [ Compound Extension Match ]
   case "$filename" in *.tar.gz)
   ├── ext="tar.gz"
   └── stem="${filename%.tar.gz}" -> api-gateway.v2
                         │
                         ▼
           [ Routing Classification ]
   case "$ext" in
   ├── tar.gz|zip)  category="archives"
   ├── json|yaml)   category="configs"
   ├── sql)         category="databases"
   └── *)           category="miscellaneous"
                         │
                         ▼
           [ Atomic Move & TSV Indexing ]
   mkdir -p "catalog_out/$category"
   mv "$filepath" "catalog_out/$category/$filename"
   echo "$filename\t$category\t$stem\t$ext" >> catalog_out/catalog.tsv
```

---

## 5. Self-Assessment Checklist
Before editing `sorter.sh`, answer these five questions:

1. **Why is `basename "$file"` slow when called inside a 10,000-iteration loop?**
   * *Answer*: Each invocation spawns a new process via `fork`/`execve`, creating kernel context switches and CPU cache invalidations.
2. **What does `${path##*/}` do under the hood?**
   * *Answer*: It scans the string in memory and strips the longest prefix matching `*/`, leaving only the characters following the final slash.
3. **What is the result of `${file%.*}` on `backup.2026.tar.gz`?**
   * *Answer*: It strips the shortest suffix matching `.*`, yielding `backup.2026.tar`.
4. **How do you detect if a filename has no dot/extension using pure Bash?**
   * *Answer*: Check with `[[ "$filename" != *.* ]]` or a `case` pattern.
5. **Why should you avoid piping into `cut -d. -f2` to extract file extensions?**
   * *Answer*: Piped commands spawn two subshells and fail on multi-dot filenames like `api.v1.0.json`.

---

## 6. Mission Objectives
Implement `sorter.sh` as a high-performance in-memory artifact cataloguer:
1. Accept optional `<input_dir>` (default: `incoming`) and `<dest_dir>` (default: `catalog_out`).
2. Zero external binaries: strictly no `basename`, `dirname`, `cut`, `sed`, `awk`, `tr`, `python`, `perl`.
3. Extract `dir`, `filename`, `ext`, and `stem` in pure Bash memory.
4. Accurately handle compound extensions (`tar.gz`, `tar.bz2`, `tar.xz`, `backup.sql`) and files with no extension (`none`).
5. Route files into categorized subfolders:
   - `archives`: `tar.gz`, `tar.bz2`, `tar.xz`, `zip`, `gz`
   - `configs`: `json`, `yaml`, `yml`, `toml`, `conf`
   - `databases`: `sql`, `backup.sql`
   - `binaries`: `bin`, `sh`, or `none`
   - `miscellaneous`: all others
6. Move each file to `<dest_dir>/<category>/<filename>`.
7. Generate `<dest_dir>/catalog.tsv` with tab-separated entries:
   `BASENAME\tCATEGORY\tSTEM\tEXT`
8. Output summary: `CATALOG_COMPLETE: processed=<N>, categories=<M>`.
