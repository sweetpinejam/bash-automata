# Tactical Field Manual: Stream-Safe While Loops

## 1. The Mental Model (Why `for line in $(cat file)` Destroys Data)
Iterating line-by-line is one of the most frequent tasks in automation.
Yet many newcomers write:
```bash
# 💥 CATASTROPHIC BUG:
for line in $(cat file.txt); do
    echo "$line"
done
```
**Why this breaks:**
1. Command substitution `$(cat file.txt)` expands the whole file into the shell argument list.
2. The shell applies **Word Splitting** on default `IFS` (space, tab, newline).
3. If a line contains 5 words, the `for` loop executes **5 times** instead of once!
4. All tabs, spaces, and formatting are destroyed.

---

## 2. The Solution: `while IFS= read -r line`
The canonical, bulletproof way to stream any file line-by-line in POSIX and Bash is:

```bash
while IFS= read -r line || [[ -n "$line" ]]; do
    echo "$line"
done < "file.txt"
```

Let's break down each element:
* **`read`**: Reads one line from standard input.
* **`IFS=`**: Setting the Internal Field Separator to empty *just for the read command* prevents `read` from stripping leading or trailing whitespace (essential for YAML, Python, and indented configs).
* **`-r`**: "Raw input". Prevents `read` from treating backslashes `\` as escape characters. Without `-r`, `\n` becomes `n` and Windows paths or regexes are butchered.
* **`|| [[ -n "$line" ]]`**: If the input file does not have a trailing newline on the last line, `read` returns status 1 after reading the line. The `|| [[ -n "$line" ]]` guard ensures that final line is still processed.
* **`< "file.txt"`**: Direct file redirection into the loop.

---

## 3. Deadly Pitfall: Forgetting `IFS=` or `-r`
```bash
# Trims indentation and deletes backslashes:
while read line; do ... done

# Preserves exact byte formatting:
while IFS= read -r line; do ... done
```

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `read [-ers]`)
* Greg's Bash Wiki: [BashFAQ/001: How can I read a file (data stream, variable) line-by-line?](https://mywiki.wooledge.org/BashFAQ/001)
* ShellCheck Wiki: Rule `SC2013` (To read lines, use while read)

---

## 5. Mission Objective
Edit `compiler.sh` in your sandbox. Replace the broken `for line in $(cat ...)` with the canonical `while IFS= read -r line || [[ -n "$line" ]]` loop reading from `template.conf`.
Ensure `final.conf` matches `template.conf` byte-for-byte.
