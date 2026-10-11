# Code Blueprint: Stream Pipeline Line-Buffering

By default, GNU C library (`glibc`) buffers pipes in 4096-byte blocks. Force immediate output per line using `--line-buffered` or `stdbuf`:

```bash
# Blueprint Pattern:
# With GNU grep:
bash producer.sh | grep --line-buffered "ALERT" > "$output_file"

# Or with stdbuf utility for generic tools:
stdbuf -oL -eL bash producer.sh | grep --line-buffered "ALERT" > "$output_file"
```

> **Key Rule**: Piping stdout to a file or another process switches glibc stream buffering from line-buffered (`\n`) to block-buffered (4KB). `--line-buffered` prevents downstream stall.
