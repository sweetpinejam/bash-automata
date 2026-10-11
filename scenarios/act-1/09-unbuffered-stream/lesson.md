# Tactical Field Manual: The Unbuffered Stream (Libc 4KB Stdio Buffering)

## 1. The Architecture (Why Pipes Buffer in 4KB Blocks)
In the C standard library (`libc`), input/output streams (`stdio`) adjust their buffering policy dynamically based on where they write:

1. **Connected to a Terminal (TTY)**:
   - Mode: **Line-Buffered** (`_IOLBF`).
   - The buffer flushes immediately whenever a newline `\n` is printed.
2. **Connected to a Pipe or File**:
   - Mode: **Block-Buffered** (`_IOFBF`).
   - The buffer collects bytes until reaching **4,096 bytes (4 KB)** or 8,192 bytes before flushing to the kernel!

```
  [ Producer ] ──▶ [ grep in Pipe ] ──( 4 KB Buffer Holding Data... )──▶ [ Consumer Waits ]
                          │
                   (Stalled until 4KB fills!)
```

If your microservice logs 50 bytes per second, a downstream pipe (`cmd | grep ALERT | monitor`) will **freeze for 80 seconds** before dumping a sudden burst of 4,000 bytes!

---

## 2. The Solution: Enforcing Line Buffering

### Tool-Specific Flags:
- **`grep`**: Use `grep --line-buffered`
- **`sed`**: Use `sed -u` (unbuffered)
- **`awk`**: Call `fflush()` after print, or `stdbuf`
- **`python`**: Run with `python3 -u` or set `PYTHONUNBUFFERED=1`

### Universal Wrapper: GNU `stdbuf`
GNU Coreutils provides **`stdbuf`**, which preloads a shared library to alter `libc` stream buffers for *any* compiled executable:
```bash
# Force stdout (-oL) and stderr (-eL) to line-buffered mode:
stdbuf -oL -eL command | downstream
```

---

## 3. Recommended Reading List
* `man 1 stdbuf` (Modifying stdio buffering)
* `man 3 setvbuf` (C library buffering modes: `_IONBF`, `_IOLBF`, `_IOFBF`)
* PixelBeat: [Stdio Output Buffering](https://www.pixelbeat.org/programming/stdio_buffering/)

---

## 4. Mission Objective
Edit `pipeline.sh` in your sandbox. Enable line-buffering so that incoming alert events flow across the pipe immediately with zero block-buffering latency.
Verify with `[4] Run State Verification`.
