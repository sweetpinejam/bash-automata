# Code Blueprint: High-Throughput In-Memory Buffers via `/dev/shm`

Bypass filesystem disk I/O bottlenecks for sub-millisecond IPC data buses using Linux kernel RAM disk:

```bash
# Blueprint Pattern:
BUS_FILE="/dev/shm/telemetry_bus_$$.dat"
trap 'rm -f "$BUS_FILE"' EXIT INT TERM

# Write frames directly to RAM memory:
for (( i=1; i<=100; i++ )); do
  echo "FRAME_$i load=0.55 temp=42C" > "$BUS_FILE"
  sleep 0.005
done
```

> **Key Rule**: Files written to `/dev/shm` live directly in volatile system RAM (`tmpfs`), avoiding storage block-layer I/O and SSD wear.
