# Tactical Field Manual: The String Surgeon

## 1. The Mental Model (In-Memory Parameter Pattern Trimming)
In legacy shell scripts, engineers often called `basename`, `dirname`, `cut`, or `sed` to slice filenames.
Every command invocation inside a loop forks a new operating system process (`clone()` / `fork()`), incurring heavy kernel context switching. For a loop over 1,000 files, calling external binaries takes seconds instead of milliseconds.

Bash has built-in pattern stripping that operates **directly in memory** inside the shell process:

```
               Prefix Trimming (#)               Suffix Trimming (%)
         ┌──────────────────────────────┐ ┌──────────────────────────────┐
         │ ${VAR#pattern}  (shortest)   │ │ ${VAR%pattern}  (shortest)   │
         │ ${VAR##pattern} (longest)    │ │ ${VAR%%pattern} (longest)    │
         └──────────────────────────────┘ └──────────────────────────────┘
```

> **Memory Trick**:
> - `#` is on the left side of the keyboard number row (or US dollar sign) $\rightarrow$ trims from the **FRONT / LEFT**.
> - `%` is further right $\rightarrow$ trims from the **BACK / RIGHT**.
> - Single character (`#` or `%`) trims the **shortest** match.
> - Double character (`##` or `%%`) trims the **longest** match (greedy).

---

## 2. Syntax Cheatsheet: Common Use Cases

Given: `FILEPATH="/var/data/archive/app.v2.tar.gz"`

```bash
# 1. Get the filename (strip everything up to the LAST slash):
echo "${FILEPATH##*/}"
# Output: app.v2.tar.gz

# 2. Get the directory (strip everything from the LAST slash to the end):
echo "${FILEPATH%/*}"
# Output: /var/data/archive

# 3. Get the trailing file extension (strip everything up to the LAST dot):
echo "${FILEPATH##*.}"
# Output: gz

# 4. Strip the trailing extension (strip from the LAST dot to the end):
echo "${FILEPATH%.*}"
# Output: /var/data/archive/app.v2.tar

# 5. Get the bare name (strip path, then strip everything after the FIRST dot):
fname="${FILEPATH##*/}"
echo "${fname%%.*}"
# Output: app
```

---

## 3. Deadly Pitfall in High-Volume Automation
Using `basename` and `cut` inside automation loops:
```bash
# ❌ SLOW: 2 subprocess forks per file loop
for f in *; do
    name=$(basename "$f")
    ext=$(echo "$name" | cut -d. -f2)
done

# ✅ LIGHTNING FAST: 0 subprocess forks (pure in-memory)
for f in *; do
    name="${f##*/}"
    ext="${name##*.}"
done
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `Remove matching prefix pattern`)
* Greg's Bash Wiki: [ParameterExpansion#Pattern_removal](https://mywiki.wooledge.org/ParameterExpansion#Pattern_removal)
* Bash Hackers Wiki: Parameter Expansion (Strings)

---

## 5. Mission Objective
Edit `sorter.sh` in your sandbox. Replace the broken assignments with `${filepath##*/}` and `${filename##*.}` so the automated sorter bins all artifacts into `categorized/<ext>/<filename>` cleanly with exit code 0.
