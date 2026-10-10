# Tactical Field Manual: The Subshell Ghost (Pipeline Scoping Trap)

## 1. The Mental Model (Why Piped Loops Erase Variables)
In POSIX-compliant shells, **every stage of a pipeline (`|`) runs in its own subshell**.
A subshell is a separate child process created via Linux `clone()` / `fork()`.
While a child process inherits a snapshot copy of its parent's variables, **changes made in a child process can NEVER propagate back to the parent process**.

Consider this code:
```bash
count=0
cat file.txt | while read line; do
    (( count++ ))    # Modifies 'count' ONLY inside the child subshell!
done

echo "$count"       # Outputs: 0! The child process has exited and died.
```
This is the notorious **Subshell Ghost** bug.

---

## 2. The Solution: Process Substitution `< <(...)`
To stream the output of a command into a `while` loop *without piping*:

```bash
count=0
while IFS= read -r line; do
    (( count += 1 ))
done < <(grep "ERROR" /var/log/app.log)

echo "$count"   # Outputs: 42 (Preserved in the main shell!)
```

### How `< <(cmd)` Works:
- The inner `<(cmd)` is **Process Substitution**. The OS runs `cmd` connected to a named pipe (or `/dev/fd/63`).
- The outer `<` is standard **input redirection**.
- Because the `while` loop is now receiving redirected input rather than being part of a pipeline, **the loop executes directly inside the current shell process**.
- All variables survive!

---

## 3. Alternative: Direct File Redirection
If you are reading an existing file directly:
```bash
while IFS= read -r line; do
    (( total += 1 ))
done < "data.csv"
```
*(If you need to skip headers, use `< <(tail -n +2 data.csv)`).*

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `Process Substitution`)
* Greg's Bash Wiki: [BashFAQ/024: I set variables in a loop that's in a pipeline. Why do they disappear after the loop terminates?](https://mywiki.wooledge.org/BashFAQ/024)
* Advanced Bash-Scripting Guide: Chapter 11 (Subshells)

---

## 5. Mission Objective
Edit `auditor.sh` in your sandbox. Eliminate the pipeline `tail ... | while ...` and replace it with `while ... done < <(tail -n +2 ledger.csv)` so that `total_amount` accurately survives the loop and outputs `$3,750`.
