# Structural Scaffolding: Stream Pipeline Line-Buffering

When streaming event data through intermediate command-line filters across pipes, standard utilities buffer stdout in 4,096-byte blocks, preventing real-time delivery.

---

## Pattern A: Utility-Specific Line-Buffering

For tools that provide native command-line options:

```bash
# GNU grep:
producer | grep --line-buffered "PATTERN" > "$output_file"

# GNU sed:
producer | sed -u 's/filter/replacement/' > "$output_file"

# Python scripts:
python3 -u processor.py
```

---

## Pattern B: Universal Libc Stream Injection (`stdbuf`)

For utilities without native line-buffering flags:

```bash
# -oL forces stdout to line-buffered (_IOLBF)
# -eL forces stderr to line-buffered
stdbuf -oL -eL generic_tool | downstream_consumer
```

---

## Verifying Real-Time Stream Delivery

Observe real-time arrival of streaming events without block delays:
```bash
# Follow the live stream:
tail -f events.stream
```
Every event should appear in the output stream as soon as the producer emits it.
