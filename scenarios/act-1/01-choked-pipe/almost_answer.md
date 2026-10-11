# Code Blueprint: Decoupling Pipelines with Named Pipes (FIFO)

When anonymous pipes (`|`) block upstream producers during consumer spikes, decouple them with a filesystem FIFO:

```bash
# Blueprint Pattern:
FIFO_PATH="stream_$$.fifo"
mkfifo "$FIFO_PATH"
trap 'rm -f "$FIFO_PATH"' EXIT INT TERM

# Launch consumer in background reading from FIFO:
python3 process.py < "$FIFO_PATH" &
consumer_pid=$!

# Stream standard input into the FIFO:
cat > "$FIFO_PATH"

# Wait for background consumer to finish:
wait "$consumer_pid"
```

> **Key Rule**: A FIFO blocks until both a reader and writer open it. Running the reader in the background (`&`) prevents writer deadlock.
