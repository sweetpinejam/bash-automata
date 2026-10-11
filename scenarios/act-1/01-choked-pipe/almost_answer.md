# Tactical Blueprint: Decoupling Pipelines with Named Pipes (`mkfifo`)

When synchronous anonymous pipes (`|`) choke upstream producers due to consumer micro-stalls, decouple them using an asynchronous filesystem FIFO.

---

## 1. The Decoupled FIFO Pattern

```bash
FIFO_PATH="./stream_$$.fifo"

# Guard: Register cleanup trap BEFORE creating the filesystem node
trap 'rm -f "$FIFO_PATH"' EXIT INT TERM

# Allocate the named pipe
mkfifo "$FIFO_PATH"

# CRUCIAL: Launch the consumer in the BACKGROUND reading from the FIFO first
python3 process.py < "$FIFO_PATH" &
CONSUMER_PID=$!

# Stream incoming data directly into the FIFO
cat > "$FIFO_PATH"

# Wait for background consumer to finish processing all records
wait "$CONSUMER_PID"
```

---

## 2. Key Mechanics & Gotchas
* **Deadlock Prevention**: In POSIX, `cat > "$FIFO_PATH"` will block indefinitely if no reader has opened the FIFO. You **must** spawn the background reader (`python3 ... < "$FIFO_PATH" &`) before writing to the pipe.
* **Zero Disk Footprint**: Even though `mkfifo` creates a directory entry in the filesystem, all data exchanges happen purely in kernel memory pages.
* **Deterministic Cleanup**: `trap 'rm -f "$FIFO_PATH"' EXIT INT TERM` ensures the special file is unlinked whether the script exits normally or crashes via `set -e`.
