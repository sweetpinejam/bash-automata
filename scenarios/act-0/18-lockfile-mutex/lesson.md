# Tactical Field Manual: The Lockfile Mutex (Atomic Filesystem Locking)

## 1. The Mental Model (Why `[ -f lock ]` Suffers from TOCTOU)
When automation bots or cron jobs execute periodically, preventing concurrent runs is crucial.
A common mistake is:
```bash
# 💥 THE TOCTOU RACE CONDITION:
if [ ! -f /tmp/app.lock ]; then
    # <-- Window of vulnerability! (Process 2 can execute here)
    touch /tmp/app.lock
    run_job
    rm /tmp/app.lock
fi
```
**Why this fails**:
Between checking if the file exists and creating it, the operating system can context-switch to another process. Both processes see that `/tmp/app.lock` doesn't exist, both create it, and both run concurrently, causing race conditions and database corruption. This is a classic **Time-of-Check to Time-of-Use (TOCTOU)** vulnerability.

---

## 2. The Solution: Atomic `mkdir`
In the POSIX kernel VFS specification, the `mkdir` system call is **atomic**.
The check for directory existence and creation happen in a single kernel operation that cannot be interleaved.

- If the directory does NOT exist, the kernel creates it and returns exit code **0**.
- If the directory ALREADY exists, the kernel fails with `EEXIST` and returns exit code **1**.

```bash
LOCK_DIR="/tmp/app.lock"

# Attempt atomic acquisition
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "ERROR: Another instance is already running." >&2
    exit 1
fi

# Ensure unlock happens regardless of how the script terminates:
trap 'rmdir "$LOCK_DIR"' EXIT
```

> **Crucial Rule**: Never use `mkdir -p` for mutual exclusion! `mkdir -p` does not error if the directory already exists, defeating the entire purpose of the lock.

---

## 3. Alternative: Linux `flock`
On modern Linux systems with `util-linux`, the `flock` binary provides kernel-level file descriptor advisory locking:
```bash
exec 200>/var/lock/mybot.lock
flock -n 200 || { echo "Already running"; exit 1; }
```
`mkdir` is the universal POSIX-portable standard that works everywhere without dependencies.

---

## 4. Recommended Reading List
* `man 2 mkdir` (Notice atomic error code `EEXIST`)
* Greg's Bash Wiki: [BashFAQ/045: How can I ensure that only one instance of a script is running at a time?](https://mywiki.wooledge.org/BashFAQ/045)
* Wikipedia: [Time-of-check to time-of-use](https://en.wikipedia.org/wiki/Time-of-check_to_time-of-use)

---

## 5. Mission Objective
Edit `worker.sh` in your sandbox. Implement an atomic mutex using `mkdir "$LOCK_DIR"` paired with `trap 'rmdir "$LOCK_DIR"' EXIT` to prevent overlapping runs.
Verify with `[4] Run State Verification`.
