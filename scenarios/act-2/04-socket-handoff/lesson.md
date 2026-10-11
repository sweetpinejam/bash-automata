# Tactical Field Manual: The Unix Socket Handoff

> **Incident Class**: IPC Socket Lifecycle, Stale Binds & Readiness Races  
> **Key Tooling**: `[[ -S "$SOCK" ]]`, `kill -0` process polling, Stale socket unlinking

---

## 1. The Incident: The "Address Already in Use" Trap

Unlike TCP ports (which enter `TIME_WAIT`), Unix Domain Sockets (`AF_UNIX`) exist as special inode entries on the Linux filesystem.
When a server calls `bind("daemon.sock")`:
1. If the file `daemon.sock` **already exists** (even from a dead or killed process), the Linux kernel aborts with `EADDRINUSE` (*Address already in use*).
2. If `kill -9` is sent to a running daemon, its in-memory signal handlers never execute, leaving a orphaned socket file on disk.

When an automation script restarts a service naively:
```bash
kill "$PID"
python3 daemon.py &
echo "RESTARTED"
```
Clients immediately query the socket before the new process has executed `listen()`, triggering immediate `Connection refused` outages.

---

## 2. Architecture: Zero-Drop Socket Lifecycle

```
  1. STOP PHASE:
     kill -TERM $PID ──► Wait until `kill -0 $PID` fails (Process dead)
     rm -f daemon.sock ──► Unlink residual socket file
     
  2. START PHASE:
     python3 daemon.py & ──► Spawn new daemon in background
     
  3. READINESS BARRIER:
     Loop [[ -S daemon.sock ]] && client_probe
     [WAIT...] ──► Socket bound and accepting connections!
     
  4. RETURN:
     echo "RESTART_COMPLETE" ──► Safe for downstream traffic!
```

---

## 3. Key POSIX Tests for Sockets

- `[[ -S "$PATH" ]]`: Returns true if the file exists AND its file mode is a socket (`S_IFSOCK`).
- `kill -0 "$PID"`: Tests if a process with `$PID` is currently alive without sending any actual signal. Returns 0 if alive, non-zero if dead or non-existent.
