# Tactical Field Manual: The Exponential Backoff Retry Loop

## 1. The Mental Model (Handling Transient Failures in Distributed Systems)
In modern microservice architectures, transient errors happen constantly:
- Services are booting up and warming caches.
- Network routes flap temporarily.
- Databases rebalance leadership.

If an automated script fails on the first attempt, it creates brittle deployment pipelines.
Conversely, if an automation script retries in a tight loop:
```bash
# 💥 BUSY-WAIT DISASTER (100% CPU usage & thundering herd):
while ! curl https://api.service/health; do :; done
```
This overwhelms the recovering service and burns 100% host CPU.

---

## 2. The Solution: Exponential Backoff Polling
Exponential backoff increases the sleep delay exponentially between consecutive failures:
- Attempt 1: Fail $\rightarrow$ Sleep $1\times$
- Attempt 2: Fail $\rightarrow$ Sleep $2\times$
- Attempt 3: Fail $\rightarrow$ Sleep $4\times$
- Attempt 4: Fail $\rightarrow$ Sleep $8\times$

```bash
attempt=1
max_attempts=5
delay=1

while (( attempt <= max_attempts )); do
    if query_service; then
        echo "SERVICE_READY"
        exit 0
    fi

    echo "Attempt $attempt failed. Retrying in ${delay}s..."
    sleep "$delay"
    (( attempt += 1 ))
    (( delay *= 2 ))
done

echo "ERROR: Service probe timed out" >&2
exit 1
```

---

## 3. Deadly Pitfall: Missing Bounded Max Attempts
A retry loop that does not enforce `(( attempt <= max_attempts ))` will run forever if the upstream service suffers a permanent outage, deadlocking your CI runner and exhausting cloud build minutes.
Always cap retry loops with explicit limits.

---

## 4. Recommended Reading List
* AWS Architecture Blog: [Exponential Backoff And Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
* Google Cloud SRE Book: Chapter 22 (Addressing Cascading Failures)
* GNU Coreutils: `man 1 sleep` (Notice fractional second support: `sleep 0.5`)

---

## 5. Mission Objective
Edit `probe.sh` in your sandbox. Implement an exponential backoff loop querying `./mock_service.sh` with `max_attempts=4`, doubling `delay_ms` on each failure.
Verify with `[4] Run State Verification`.
