# Structural Scaffolding: High-Throughput In-Memory Buffers via `/dev/shm`

To bypass physical storage journaling and I/O wait overhead during high-frequency telemetry streaming, relocate the buffer file to the Linux kernel `tmpfs` RAM disk while preventing memory leaks.

---

## Pattern: Isolated tmpfs Buffer with Lifecycle Trap

```bash
# 1. Direct the buffer to the tmpfs mount:
BUS_FILE="/dev/shm/telemetry_bus.dat"

# 2. Defensively register an EXIT trap to prevent permanent RAM leaks in tmpfs:
MAIN_PID=$$
trap 'if [[ "$BASHPID" == "$MAIN_PID" ]]; then rm -f "$BUS_FILE"; fi' EXIT INT TERM

# 3. Stream telemetry frames directly at DRAM bus speeds:
for (( i=1; i<=TOTAL_FRAMES; i++ )); do
    echo "FRAME_$i ..." > "$BUS_FILE"
    sleep "$INTERVAL"
done
```

---

## Verifying Zero Leaks

Inspect `/dev/shm` during and after execution:
```bash
# During execution (file should exist in RAM):
ls -lh /dev/shm/telemetry_bus.dat

# After execution terminates (file must be completely cleaned up):
ls -lh /dev/shm/telemetry_bus.dat
# Expected: ls: cannot access '/dev/shm/telemetry_bus.dat': No such file or directory
```
