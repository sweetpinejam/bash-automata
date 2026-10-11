# Tactical Field Manual: The Silent Deadlock (Bidirectional FIFO Blocking)

## 1. The Architecture (How POSIX Handles FIFO Opens)
A Named Pipe (`mkfifo`) implements standard Unix stream semantics across the filesystem.
However, the POSIX specification defines a strict synchronization contract for opening FIFOs:
- Calling `open(fifo, O_RDONLY)` **blocks indefinitely** until another process opens the FIFO for writing (`O_WRONLY`).
- Calling `open(fifo, O_WRONLY)` **blocks indefinitely** until another process opens the FIFO for reading (`O_RDONLY`).

```
    Process A                          Kernel FIFO                         Process B
 ─────────────────                  ─────────────────                  ─────────────────
  open(resp, READ)  ───(blocks)──▶      [ resp.fifo ]      ◀──(waiting)──  open(resp, WRITE)
         │                                                                         ▲
         ▼                                                                         │
   (NEVER REACHED)                                                         (NEVER REACHED)
  open(req, WRITE)  ───(waiting)─▶      [ req.fifo ]       ◀──(blocks)───  open(req, READ)
```

If **Process A** waits to read `resp.fifo` before writing to `req.fifo`, while **Process B** waits to read `req.fifo` before writing to `resp.fifo`, **both processes enter an uninterruptible sleep state** waiting for each other.
This is a classic **Circular Dependency Deadlock**.

---

## 2. The Solution: Asynchronous Handshakes
To break the deadlock, at least one half of the handshake must be decoupled:

### Pattern A: Backgrounding the Writer
```bash
# Write PING asynchronously in the background so it doesn't block:
echo "PING" > req.fifo &

# Now reading the response will complete when the controller replies:
cat resp.fifo > handshake.log
```

### Pattern B: Non-Blocking Opens (`exec 3<>`)
In Linux, opening a pipe in read-write mode avoids the blocking wait:
```bash
exec 3<> req.fifo
echo "PING" >&3
```

---

## 3. Production Triage: Spotting Pipe Deadlocks
When processes freeze silently in production, inspect their state in `/proc`:
```bash
# Check process state (S = sleeping, D = disk/IO wait)
ps -o pid,stat,wchan,cmd -p $PID

# Inspect blocked file descriptors:
lsof -p $PID
```
If `wchan` shows `pipe_wait` or `fifo_open`, your pipeline is deadlocked on an un-serviced FIFO.

---

## 4. Recommended Reading List
* `man 7 fifo` (FIFO special files & blocking semantics)
* W. Richard Stevens: Advanced Programming in the UNIX Environment (Chapter 15: IPC & FIFOs)
* Linux Kernel Documentation: IPC Pipe Buffers

---

## 5. Mission Objective
Edit `agent.sh` in your sandbox. Decouple the request and response handshake so that `agent.sh` and `controller.py` communicate cleanly without deadlocking. Verify with `[4] Run State Verification`.
