# Code Blueprint: Bidirectional Named Pipe Handshake Deadlock Prevention

When two processes communicate across two FIFOs (`req.fifo` and `resp.fifo`), synchronization ordering is critical:

```bash
# Blueprint Pattern:
# If peer controller waits to read req.fifo before writing to resp.fifo:
# Write request asynchronously in background so reading doesn't block:
echo "PING" > req.fifo &

# Now reading resp.fifo proceeds without freezing:
cat resp.fifo > handshake.log

# Wait for background processes to settle:
wait "$controller_pid"
```

> **Key Rule**: Opening a FIFO for writing (`> req.fifo`) blocks until the reader opens it, and opening for reading (`< resp.fifo`) blocks until the writer opens it. Asynchronous execution (`&`) breaks circular dependency deadlocks.
