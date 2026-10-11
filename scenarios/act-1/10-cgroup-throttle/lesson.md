# Tactical Field Manual: The Kernel Cgroup Throttle (O(1) Streaming vs OOM Kills)

## 1. The Architecture (Linux Cgroups & The OOM Killer)
In containerized architectures (Docker, Kubernetes, systemd slices), processes run under strict resource controls managed by Linux **Control Groups (cgroups)**:
- `memory.max`: Maximum RAM allocated to the container (e.g. 32 MB).

When a process inside the container allocates memory faster than the kernel can reclaim:
1. The kernel memory subsystem invokes the **OOM (Out-of-Memory) Killer**.
2. The kernel delivers an un-catchable **`SIGKILL` (Signal 9)** to the process.
3. The process is slaughtered instantly without executing any cleanup or saving state.

---

## 2. The Trap: In-Memory Array Buffering in Shell
A common mistake in shell automation is buffering incoming datasets into memory:
```bash
# 💥 CATASTROPHIC OOM RISK:
records=()
while read -r line; do
    records+=("$line")   # Allocates dynamically growing memory in shell heap!
done < large_file.log
```
Bash arrays have massive memory overhead per element (string pointers, metadata, reallocations). Storing 50,000 lines can bloat Bash from 4MB to over 100MB of RAM, instantly triggering an OOM kill.

---

## 3. The Solution: Stream Processing ($O(1)$ Constant Memory)
Unix was explicitly architected around the stream paradigm.
By piping input directly to output, **memory consumption remains completely constant ($O(1)$)** whether processing 10 lines or 10,000,000 lines:

```bash
# Constant memory footprint: Peak RSS < 8 MB regardless of dataset size!
while IFS= read -r line; do
    echo "PROCESSED: $line"
done < feed.raw > processed.log
```

---

## 4. Recommended Reading List
* `man 7 cgroups` (Control groups overview)
* Linux Kernel Documentation: [cgroup-v2 Memory Controller](https://www.kernel.org/doc/Documentation/cgroup-v2.txt)
* Brendan Gregg: BPF Performance Tools (Memory Profiling)

---

## 5. Mission Objective
Edit `ingest.sh` in your sandbox. Eliminate the in-memory array buffer and stream all 5,000 records directly from `feed.raw` to `processed.log`. Ensure peak memory remains strictly under 15MB.
Verify with `[4] Run State Verification`.
