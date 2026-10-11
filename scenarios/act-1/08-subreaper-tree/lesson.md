# Tactical Field Manual: The Subreaper Tree (Process Groups & Cascading Teardown)

## 1. The Architecture (The Grandchild Orphan Problem)
In Linux process management, when process A forks process B, and process B forks process C:
```
  [ Orchestrator A ] ──▶ [ Pipeline B (Child) ] ──▶ [ Worker C (Grandchild) ]
```

When you kill Process B using standard `kill $PID`:
1. The kernel terminates Process B.
2. But Process C (the grandchild) is **NOT automatically killed**!
3. The kernel **re-parents** Process C to `PID 1` (init / systemd).
4. Process C continues running in the background indefinitely as an **orphan**.

In automated testing, CI pipelines, and microservice hosts, orphaned grandchildren keep holding ports, consuming RAM, and locking files long after the test suite claims to be finished.

---

## 2. Solution Strategies in Linux

### Strategy A: Process Tree Killing (`pkill -P $PID`)
The `pkill` tool allows targeting all processes whose Parent PID (PPID) matches the target:
```bash
# Terminate all children of the pipeline first:
pkill -P "$pipeline_pid"
# Then terminate the pipeline itself:
kill -TERM "$pipeline_pid"
```

### Strategy B: Subshell Trap Propagation
Inside the child script (`pipeline.sh`), register an EXIT trap to murder all of its own background jobs:
```bash
trap 'pkill -P $$ 2>/dev/null || true' EXIT TERM INT
```

### Strategy C: Process Groups (`kill -- -$PGID`)
If the pipeline is launched in its own process group (`set -m`), passing a negative PID to `kill` sends the signal to **every process in that group**:
```bash
kill -TERM -- "-$PGID"
```

---

## 3. Recommended Reading List
* `man 1 pkill` (Notice: `-P ppid` flag for matching parent process)
* `man 2 setpgid` (Setting process group IDs)
* Advanced Bash-Scripting Guide: Chapter 12 (Process Control & Job IDs)

---

## 4. Mission Objective
Edit `orchestrator.sh` in your sandbox. Ensure that when the pipeline workload is torn down, all grandchild worker tasks are terminated cleanly with zero orphaned processes surviving in the process table.
Verify with `[4] Run State Verification`.
