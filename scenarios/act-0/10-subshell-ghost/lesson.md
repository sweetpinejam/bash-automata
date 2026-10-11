# Tactical Field Manual: The Subshell Ghost (Process Scoping & Process Substitution)

## 1. Systems Mental Model: Unix Pipelines & Memory Isolation
The most baffling bug for intermediate Bash developers is the vanishing variable:
```bash
total=0
cat numbers.txt | while read -r n; do
    (( total += n ))
done
echo "Total is: $total"  # 💥 ALWAYS PRINTS: Total is: 0 !
```
Why does `total` stay 0 even though the loop ran thousands of times?

### What Happens in the Linux Kernel During a Pipeline (`|`)
In POSIX shell specifications, every command in a pipeline runs in a separate **subshell** (a distinct child process):

```
[ Parent Shell Process (PID: 1000) ]
  ├── Variable: total = 0
  │
  ├── pipe(2) created between Child 1 and Child 2
  │
  ├── fork(2) -> [ Child Process 1 (PID: 1001) ]: cat numbers.txt
  │
  └── fork(2) -> [ Child Process 2 (PID: 1002) ]: while read ...
                 ├── Memory Page: total = 0 (Inherited COW copy)
                 ├── Loop increments: total becomes 4500
                 └── Loop finishes -> Process exits! Memory destroyed!

[ Parent Shell Process resumes ]
  └── Memory was NEVER modified! total is still 0!
```

Because Linux processes have **strict virtual memory isolation**, Child 2 cannot modify the memory pages of Parent 1000. When Child 2 exits, its page tables are reclaimed by the kernel. The mutated variables evaporate into the void.

---

## 2. The Solution: Process Substitution (`< <(cmd)`)

To keep the while loop running inside the **parent shell process**, you must feed the command's output into the loop using **Process Substitution**:

```bash
total=0
while IFS= read -r n; do
    (( total += n ))
done < <(cat numbers.txt)

echo "Total is: $total"  # ✅ PRINTS: Total is: 4500!
```

### How Process Substitution Works
Look closely at the syntax: `< <(cmd)`
1. The inner `<(cmd)` tells Bash to run `cmd` asynchronously and connect its output to a named pipe or file descriptor: `/dev/fd/63`.
2. The outer `<` is standard input redirection: it redirects file descriptor 0 (`stdin`) of the while loop from `/dev/fd/63`.
3. **CRITICAL DIFFERENCE**: The while loop executes in the **current, parent shell process**!
4. Any variable mutations, array updates, and counter increments persist after the loop finishes.

---

## 3. Alternative: File Redirection (`< file.csv`)
If the data source is a static file on disk, you do not even need process substitution:
```bash
while IFS=, read -r a b c; do
    (( total += c ))
done < ledger.csv
```
However, if you need to filter the file (e.g. skip a CSV header with `tail -n +2`), process substitution is the clean, idiomatic Bash standard:
```bash
while IFS=, read -r a b c; do
    (( total += c ))
done < <(tail -n +2 ledger.csv)
```

---

## 4. Architectural Diagram: Subshell Pipeline vs Process Substitution

```
SCENARIO A: Broken Pipeline (| while)
┌───────────────────────────┐      ┌───────────────────────────┐
│ Parent Process (PID 100)  │      │ Subshell (PID 102)        │
│ total = 0                 │ ───> │ total = 0 -> 100 -> 2500  │
│ (Reads total -> still 0!) │      │ [EXIT: Memory Destroyed]  │
└───────────────────────────┘      └───────────────────────────┘

SCENARIO B: Process Substitution (< <(...))
┌───────────────────────────┐
│ Parent Process (PID 100)  │ <─── Reads /dev/fd/63 from <(tail -n +2)
│ while loop runs HERE!     │
│ total = 0 -> 100 -> 2500  │
│ [LOOP ENDS: total = 2500] │
└───────────────────────────┘
```

---

## 5. Self-Assessment Checklist
Before you begin modifying `auditor.sh`:

1. **Why does piping into a while loop prevent variables from updating in the parent script?**
   * *Answer*: Each stage in a pipeline runs in a separate child process (subshell). Memory modifications in child processes cannot alter parent memory.
2. **What does `<(command)` expand to in Linux?**
   * *Answer*: It expands to a file path representing an anonymous pipe, typically `/dev/fd/<number>`.
3. **What is the purpose of the leading `<` in `done < <(command)`?**
   * *Answer*: It is standard input redirection (`stdin`), redirecting the while loop's input from the `/dev/fd` stream emitted by `<(command)`.
4. **Why can't you just use `shopt -s lastpipe` everywhere?**
   * *Answer*: `lastpipe` only operates in non-interactive scripts when job control is explicitly disabled (`set +m`), making it fragile across different deployment environments. Process substitution is universally reliable.
5. **How do you declare and modify an associative array in Bash?**
   * *Answer*: `declare -A MAP; MAP["key"]=$(( ${MAP["key"]:-0} + val ))`.

---

## 6. Mission Objectives
Implement `auditor.sh` as a production financial ledger auditor and fraud detector:
1. Accept input ledger file `$1` (default: `ledger.csv`) and output report `$2` (default: `audit_report.tsv`).
2. Strictly no piped loops (`| while`). Loop must run in main shell using process substitution:
   `done < <(tail -n +2 "$INPUT_LEDGER")`.
3. Parse CSV fields: `tx_id`, `account_id`, `type`, `amount`, `auth_code`.
4. Track global metrics in main shell memory:
   - `TOTAL_TX`, `TOTAL_CREDITS`, `TOTAL_DEBITS`, `NET_BALANCE` (`CREDITS - DEBITS`).
   - Track per-account balances in an associative array: `declare -A BALANCES`.
5. Anomaly detection:
   - If `amount > 5000` and `auth_code` is `NONE`:
     - Flag transaction as fraud, increment `FLAGGED_FRAUD`.
     - Log alert to `fraud_alerts.log`:
       `[FRAUD_ALERT] tx=<tx_id> account=<account_id> amount=<amount> reason=UNAUTHORIZED_LARGE_TRANSFER`.
6. Write summary report to `audit_report.tsv`:
   `TOTAL_TX`, `TOTAL_CREDITS`, `TOTAL_DEBITS`, `NET_BALANCE`, `FLAGGED_FRAUD`, `ACCOUNTS_TRACKED`.
7. Output summary: `AUDIT_COMPLETE: txs=<N>, credits=<C>, debits=<D>, net=<B>, fraud=<F>, accounts=<A>`.
