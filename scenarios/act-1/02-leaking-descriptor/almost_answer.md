# Code Blueprint: Dynamic File Descriptor Allocation & Reclamation

When dynamically allocating file descriptors (`exec {fd}< ...`), Linux kernel tables retain each open descriptor until explicitly closed:

```bash
# Blueprint Pattern:
# Allocate descriptor dynamically into variable $fd:
exec {fd}< "$status_file"

# Read through descriptor:
read -r line <&"$fd"

# Close the allocated file descriptor:
exec {fd}<&-
```

> **Key Rule**: The syntax `exec {fd}<&-` tells the shell to close input descriptor `{fd}`. Without this, repeated loops exhaust the process `RLIMIT_NOFILE` quota.
