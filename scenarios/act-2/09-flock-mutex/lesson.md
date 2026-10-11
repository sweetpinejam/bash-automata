# Tactical Field Manual: The Advisory Lock Contest

> **Incident Class**: Concurrent File Append Interleaving & Record Tearing  
> **Key Tooling**: `flock(1)`, `exec 200>"$LOCK"`, Exclusive Locks (`-x`), Critical Sections

---

## 1. The Incident: Shared Log Interleaving & Torn Records

When multiple parallel cron tasks or background workers append multi-line records to a shared file:
```bash
# WORKER 1                     # WORKER 2
echo "START" >> shared.log     echo "START" >> shared.log
echo "payload 1" >> shared.log echo "payload 2" >> shared.log
echo "END" >> shared.log       echo "END" >> shared.log
```
The Linux kernel schedules filesystem write syscalls independently. Because writes from different processes interleave, `shared.log` ends up like this:
```
START
START          <--- TORN ROW!
payload 2
payload 1
END
END
```
Downstream parsers (JSON, CSV, TSV) immediately crash or drop records.

---

## 2. Architecture: Kernel Advisory Locking (`flock`)

```
   WORKER A                              WORKER B
  ┌─────────────────────────┐           ┌─────────────────────────┐
  │ exec 200>metrics.lock   │           │ exec 200>metrics.lock   │
  │ flock -x 200 (ACQUIRED) │           │ flock -x 200 (BLOCKED)  │
  │                         │           │      ▲                  │
  │ Appends atomic record   │           │      │                  │
  │                         │           │      │                  │
  │ flock -u 200 (RELEASE)  ├───────────┼──────┘ (NOW ACQUIRED!)  │
  └─────────────────────────┘           │ Appends atomic record   │
                                        │ flock -u 200            │
                                        └─────────────────────────┘
```

---

## 3. Best Practices with `flock`

- **Dedicated Descriptors**: Use high numbers like `exec 200>file.lock` to avoid colliding with stdin (0), stdout (1), or stderr (2).
- **Exclusive vs Shared**:
  - `flock -x`: Exclusive write lock (blocks all other readers and writers).
  - `flock -s`: Shared read lock (multiple readers allowed, writers blocked).
- **Auto-release**: If a process crashes unexpectedly, the Linux kernel automatically releases all file locks associated with that process when its file descriptors are closed by the kernel.
