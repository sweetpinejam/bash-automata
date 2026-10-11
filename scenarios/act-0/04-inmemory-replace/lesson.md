# Tactical Field Manual: Pure In-Memory Pattern Replacement & Stream Sanitization

## 1. Systems Mental Model: In-Memory Substitution vs `sed` Subprocesses
When developers need to sanitize, redact, or transform text in shell scripts, their instinct is often:
```bash
# ❌ THE DISASTROUS LOOP-SED ANTI-PATTERN:
while IFS= read -r line; do
    clean=$(echo "$line" | sed 's/SECRET/REDACTED/g')  # FORKS A SUBSHELL & SED ON EVERY LINE!
    echo "$clean" >> sanitized.log
done < events.raw
```
If `events.raw` has 10,000 lines, this anti-pattern invokes `fork(2)` and `execve(2)` **10,000 times**. It destroys CPU branch predictors, thrashes process tables, and takes 20–40 seconds to process a tiny 200KB file.

### Native Bash In-Memory Pattern Substitution
Bash includes a native string replacement engine that executes directly in shell memory:
```bash
# ✅ PURE IN-MEMORY (Zero Subprocesses, Sub-Millisecond Speed):
while IFS= read -r line || [[ -n "$line" ]]; do
    clean="${line//SECRET/REDACTED}"
    echo "$clean" >> sanitized.log
done < events.raw
```
This loop runs in under **50 milliseconds**—hundreds of times faster, with zero subprocess allocation.

---

## 2. Syntax Anatomy: The Parameter Replacement Matrix

Bash provides four distinct substitution modes via the slash `/` operator:

| Operator | Scope / Anchor | Behavior | Example (`STR="foo_dev_foo"`) | Output |
| :--- | :---: | :--- | :--- | :--- |
| `${VAR/pat/rep}` | **First** | Replaces only the first occurrence of `pat` | `${STR/foo/bar}` | `bar_dev_foo` |
| `${VAR//pat/rep}` | **Global** | Replaces ALL occurrences of `pat` | `${STR//foo/bar}` | `bar_dev_bar` |
| `${VAR/#pat/rep}` | **Prefix (`^`)** | Replaces `pat` ONLY if it matches the start | `${STR/#foo/bar}` | `bar_dev_foo` |
| `${VAR/%pat/rep}` | **Suffix (`$`)** | Replaces `pat` ONLY if it matches the end | `${STR/%foo/bar}` | `foo_dev_bar` |
| `${VAR//pat/}` | **Deletion** | Deletes all occurrences (omits `rep`) | `${STR//_foo/}` | `foo_dev` |

### Pattern Matching Wildcards in Expansions
The `pattern` is not a POSIX regular expression; it uses **Bash glob pattern matching**:
* `*`: Matches zero or more arbitrary characters.
* `?`: Matches exactly one character.
* `[...]`: Matches any character enclosed in the brackets (e.g. `[0-9]`, `[a-z]`).

```bash
# Replacing internal subnets:
IP="10.0.4.15"
echo "${IP/#10.0.*/*/[INTERNAL_IP]}"  # Output: [INTERNAL_IP]

# Stripping trailing URL parameters:
URL="https://api.internal/data?session=xyz123"
echo "${URL/%\?session=*/}"            # Output: https://api.internal/data
```
*(Notice the `\?` escape: literal question marks must be escaped so Bash does not interpret them as single-character wildcards).*

---

## 3. The Stream Reading Contract: Preserving Trailing Lines

When streaming line-by-line from a file or pipe in Bash, standard `while read line` exhibits two silent data-loss failure modes:

```bash
# ❌ VULNERABLE TO DATA LOSS:
while read line; do
    ...
done < file.txt
```
1. **Leading/Trailing Space Stripping**: `read` uses `IFS` to split words. If a log line begins with spaces, `read` discards them unless `IFS=` is cleared.
2. **Backslash Mangling**: `read` treats `\` as an escape character unless `-r` (raw mode) is specified.
3. **Truncated Final Line**: If the last line of `file.txt` lacks a trailing newline character (`\n`), `read` returns a non-zero exit code, causing the while loop to terminate *before* processing that line!

### The Bulletproof POSIX Stream Loop Idiom
```bash
while IFS= read -r line || [[ -n "$line" ]]; do
    # Process line...
done < input.txt
```
The `|| [[ -n "$line" ]]` ensures that even if `read` hits EOF without a trailing newline, the final buffered line is evaluated before the loop exits.

---

## 4. Architectural Diagram: In-Memory Stream Transformation

```
[ Input: events.raw ]
         │
         ▼
[ Stream-Safe Loop: while IFS= read -r line || [[ -n "$line" ]] ]
         │
         ├── 1. Prefix Replace:    ${line/#DEBUG:/[TRACE]:}
         ├── 2. Global Domain:     ${line//dev.internal/prod.external}
         ├── 3. Token Scrub:       ${line//SECRET_/REDACTED_}
         ├── 4. IP Subnet Mask:    ${line//10.0.*.*/[INTERNAL_IP]}
         └── 5. Suffix Scrub:      ${line/%\?session=*/}
         │
         ▼
[ Comparison & Metrics ]
  [[ "$line" != "$original" ]] -> Increment MODIFIED_COUNT
         │
         ├── Append to: events.sanitized
         └── Emit Audit JSON: audit_metrics.json
         │
         ▼
[ Output: SANITIZATION_COMPLETE: total=<N>, modified=<M> ]
```

---

## 5. Self-Assessment Checklist
Before you begin modifying `sanitizer.sh`:

1. **Why does `${STR/dev/prod}` differ from `${STR//dev/prod}`?**
   * *Answer*: Single slash replaces only the first occurrence; double slash replaces globally across the entire string.
2. **What does the `#` anchor in `${STR/#PREFIX/NEW}` enforce?**
   * *Answer*: It anchors the match strictly to the beginning of the string (equivalent to `^` in regular expressions).
3. **Why must a literal question mark in a pattern be escaped as `\?`?**
   * *Answer*: In globbing patterns, unescaped `?` matches any single character. Escaping it forces literal matching.
4. **Why is `|| [[ -n "$line" ]]` needed after `read -r line`?**
   * *Answer*: If the last line of a file does not terminate with `\n`, `read` returns exit code 1. The `|| [[ -n "$line" ]]` ensures the final non-empty line is processed.
5. **How does Bash in-memory parameter expansion achieve $O(1)$ process overhead?**
   * *Answer*: All string manipulation happens within the already-running shell process memory, requiring no `fork` or `execve` system calls.

---

## 6. Mission Objectives
Implement `sanitizer.sh` as a high-volume in-memory stream sanitizer:
1. Accept optional `<input_file>` (default: `events.raw`) and `<output_file>` (default: `events.sanitized`).
2. Zero external binaries: strictly no `sed`, `awk`, `cut`, `perl`, `python`.
3. Use the stream-safe loop idiom: `while IFS= read -r line || [[ -n "$line" ]]`.
4. Apply multi-pass in-memory substitutions:
   - Prefix replacement: lines starting with `DEBUG:` replaced with `[TRACE]:`.
   - Global domain replacement: `dev.internal` replaced with `prod.external`.
   - Secret token replacement: `SECRET_` replaced with `REDACTED_`.
   - Internal subnet replacement: `10.0.*.*` replaced with `[INTERNAL_IP]`.
   - Suffix scrubbing: trailing `?session=*` stripped from lines.
5. Write all sanitized lines to `<output_file>`.
6. Track metrics: `TOTAL_LINES` and `MODIFIED_LINES`.
7. Generate `audit_metrics.json` containing:
   ```json
   {
     "status": "SANITIZED",
     "total_lines": <N>,
     "lines_modified": <M>,
     "engine": "bash_in_memory"
   }
   ```
8. Output summary: `SANITIZATION_COMPLETE: total=<N>, modified=<M>, output=<output_file>`.
