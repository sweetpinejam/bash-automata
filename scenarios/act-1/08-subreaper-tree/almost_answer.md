# Code Blueprint: Process Group Signaling & Orphan Prevention

When terminating background job trees where children spawn further background descendants, signal the negative process group ID (`-PGID`):

```bash
# Blueprint Pattern:
# In Bash job control or when a script is process group leader:
pgid=$(ps -o pgid= -p "$pipeline_pid" | tr -d ' ')

# Signal the entire group (prefix PGID with minus sign):
kill -TERM -- "-$pgid" 2>/dev/null || true
```

> **Key Rule**: A negative PID argument passed to `kill` (`kill -SIGNAL -- -PGID`) signals every process in that process group in the Linux kernel, preventing orphaned background worker leaks.
