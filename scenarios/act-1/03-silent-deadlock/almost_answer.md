# Tactical Blueprint: Resolving Bidirectional FIFO Deadlocks

To break circular `open(2)` wait conditions across bidirectional named pipes:

---

## 1. Pattern A: Asynchronous Background Writer (POSIX Standard)
Decouple the outbound request by launching the writer in a background subshell (`&`), and guard the exit trap with `$BASHPID`:

```bash
MAIN_PID=$$
# Guard against subshells accidentally unlinking FIFOs when they exit:
trap 'if [[ "$BASHPID" == "$MAIN_PID" ]]; then rm -f req.fifo resp.fifo; fi' EXIT INT TERM

# 1. Fire request in the background (unblocks controller's read):
echo "PING" > req.fifo &

# 2. Block on response in the foreground (unblocks when controller responds):
cat resp.fifo > handshake.log

# 3. Cleanly wait for background child processes:
wait "$controller_pid"
```

---

## 2. Pattern B: Bidirectional File Descriptor Allocation (`exec 3<>`)
On Linux, opening a FIFO in read-write mode opens both descriptors concurrently, preventing blocking during open:

```bash
# Open in read-write mode:
exec 3<> req.fifo
echo "PING" >&3
exec 3>&-

# Read incoming response:
cat resp.fifo > handshake.log
```

---

## 3. Key Rule: Subshell Trap Defense
In Bash, background subshells inherit `EXIT` traps. If you register `trap 'rm -f req.fifo' EXIT`, the subshell `( echo PING > req.fifo ) &` will trigger the trap when it terminates, deleting the pipe while the parent is still waiting! Always check `[[ "$BASHPID" == "$MAIN_PID" ]]` inside the trap.
