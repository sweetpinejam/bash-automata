# Code Blueprint: Standard Stream Redirection (FD 1 & FD 2)

Isolate standard data output from error diagnostics using file descriptor numbers:

```bash
# Blueprint Pattern:
# Redirect stdout (FD 1) to clean.log and stderr (FD 2) to error.log:
simulate_noisy_probe > clean.log 2> error.log
```

> **Key Rule**:
> - `>` or `1>` redirects stdout (file descriptor 1).
> - `2>` redirects stderr (file descriptor 2).
