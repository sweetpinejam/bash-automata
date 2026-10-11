# Tactical Field Manual: The Exponential Backoff Retry Loop

## 1. Systems Mental Model: Transient Failures in Distributed Infrastructure
In distributed production systems, transient errors occur continuously:
* Containerized microservices warming up caches and initializing database pools.
* Ephemeral network packet drops and DNS propagation delays.
* Primary database failovers and Raft leader elections.
* API rate limiting and transient throttling (HTTP 429 / 503).

If an automation script aborts on the first failed request, deployment pipelines become brittle and unreliable.

Conversely, if an automation script retries in a tight loop without pauses:
```bash
# 💥 THE THUNDERING HERD / BUSY-WAIT DISASTER:
while ! curl -sSf http://service:8080/health; do :; done
```
* **CPU Starvation**: Spins the host CPU at 100%.
* **Self-Inflicted DDoS**: Floods the recovering service with thousands of requests per second, preventing it from ever finishing initialization (The Thundering Herd Problem).

---

## 2. Mathematical Foundation: Truncated Exponential Backoff
Exponential backoff increases the delay exponentially between consecutive failed attempts:

$$\text{delay} = \min(\text{max\_delay}, \; \text{base\_delay} \times 2^{\text{attempt} - 1})$$

| Attempt | Status | Delay Before Next Try | Cumulative Sleep |
| :--- | :--- | :--- | :--- |
| **1** | Fails | $1 \text{s}$ | $1 \text{s}$ |
| **2** | Fails | $2 \text{s}$ | $3 \text{s}$ |
| **3** | Fails | $4 \text{s}$ | $7 \text{s}$ |
| **4** | Fails | $8 \text{s}$ (capped at max) | $15 \text{s}$ |
| **5** | Exhausted | *Abort with Fatal Timeout* | *Immediate* |

---

## 3. The Deadly `(( 0 ))` Trap Under `set -e`
A subtle and notorious trap in Bash programming:
In standalone arithmetic statements `(( expr ))`, if `expr` evaluates to `0`, **Bash returns an exit code of 1** (C-style boolean logic: 0 is false)!
Under `set -e`, if `delay` is 0:
```bash
(( delay *= 2 ))   # 💥 Returns exit code 1! Script aborts immediately!
```
**The Defensive Fix**: Use arithmetic expansion within variable assignment:
```bash
delay=$(( delay * 2 ))      # Always returns exit code 0
attempt=$(( attempt + 1 ))  # Safe against zero values
```

---

## 4. Real Systems Health Probing with `curl`
When probing HTTP health endpoints, naive `curl http://...` is hazardous:
1. By default, `curl` outputs download progress meters and errors to `stderr`.
2. By default, `curl` considers HTTP `500 Internal Server Error` or `503 Service Unavailable` as **successful** (exit code `0`) because the HTTP connection itself succeeded!
3. By default, `curl` has **no connection timeout**, meaning a hung TCP socket will deadlock your script forever!

### The Production `curl` Triad:
```bash
curl -s -f -m 2 "$TARGET_URL"
```
* **`-s` (`--silent`)**: Suppresses progress meters.
* **`-f` (`--fail`)**: Treats HTTP error statuses (`4xx` and `5xx`) as fatal errors, returning exit status `22`.
* **`-m <seconds>` (`--max-time`)**: Hard execution timeout preventing hangs.

---

## 5. Architectural Diagram: Backoff Polling Sequence

```
[ Deployment Bot ]                       [ Warming-Up Microservice ]
        │                                             │
        │─── 1. curl -sSf /health ───────────────────>│ (Warming up caches...)
        │<── 503 Service Unavailable (curl exit 22) ──│
        │                                             │
  [ Sleep 1s ]                                        │
        │                                             │
        │─── 2. curl -sSf /health ───────────────────>│ (Connecting DB pools...)
        │<── 503 Service Unavailable (curl exit 22) ──│
        │                                             │
  [ Sleep 2s ]                                        │
        │                                             │
        │─── 3. curl -sSf /health ───────────────────>│ (Ready to serve traffic!)
        │<── 200 OK {"status": "READY"} (exit 0) ─────│
        │                                             │
  [ SUCCESS! ]                                        │
  - Write probe_summary.json                          │
  - Proceed with traffic routing                      │
```

---

## 6. Self-Assessment Checklist
Before modifying `probe.sh`:

1. **Why does `curl -sSf` fail with exit code 22 on HTTP 503?**
   * *Answer*: The `-f` (`--fail`) flag forces `curl` to return exit code 22 when the HTTP server returns a 4xx or 5xx status code.
2. **Why is busy-waiting (`while ! cmd; do :; done`) dangerous in cloud environments?**
   * *Answer*: It pins host CPU cores at 100% and triggers the thundering herd problem, preventing the recovering service from initializing.
3. **Why does `(( delay *= 2 ))` cause scripts to crash under `set -e` when `delay=0`?**
   * *Answer*: Because `(( 0 ))` returns exit status 1, which `set -e` treats as a fatal command failure.
4. **How do you double delay safely without triggering `set -e` failure on zero?**
   * *Answer*: By using arithmetic expansion assignment: `delay=$(( delay * 2 ))`.
5. **Why should the loop break immediately on the final attempt instead of sleeping?**
   * *Answer*: Once max attempts are exhausted, the probe has already timed out; sleeping an additional backoff delay wastes time and delays alerting.

---

## 7. Mission Objectives
Implement `probe.sh` as an enterprise health readiness probe:
1. Enable `set -euo pipefail`.
2. Accept parameters:
   - Target endpoint URL from `$1` or `$TARGET_URL` (default: `http://127.0.0.1:8080/health`).
   - Max attempts from `$2` or `$MAX_ATTEMPTS` (default: `5`).
3. Maintain exponential backoff delay starting at `1` second, doubling on each failure (`delay=$(( delay * 2 ))`), capped at `MAX_DELAY=8`.
4. Probe the target endpoint using real `curl -s -f -m 2 "$TARGET_URL"`.
5. Record attempt history into `./probe_attempts.log` (`attempt=<N> status=<STATUS> exit_code=<CODE> delay=<D> timestamp=<T>`).
6. On success:
   - Generate `./probe_summary.json` with status `SERVICE_READY`.
   - Output summary: `PROBE_SUCCESS: attempts=<N>, target=<URL>, status=READY`.
   - Exit with code 0.
7. On timeout exhaustion:
   - Generate `./probe_summary.json` with status `TIMEOUT`.
   - Output error to `stderr`: `PROBE_TIMEOUT: Exhausted <N> attempts against <URL>`.
   - Exit with code 1.
