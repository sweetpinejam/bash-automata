# Tactical Field Manual: The Atomic Swap (Zero-Downtime Deployments & `mv -T`)

## 1. The Architecture (The Symlink Release Pattern)
In modern web deployments (Capistrano, Kubernetes volumes, Blue-Green hosts), live traffic is served from a fixed directory path:
```
  /var/www/current ──(symlink)──▶ /var/www/releases/v1
```

When deploying `v2`, you must update `/var/www/current` to point to `releases/v2`.
A common, disastrous approach is:
```bash
# 💥 THE DOWNTIME WINDOW:
rm current
# <-- Window of vulnerability! (Microsecond window where current does not exist)
ln -s releases/v2 current
```
During this window, any concurrent request to `/var/www/current` fails with `404 Not Found` or `500 Server Error`.
Even `ln -sfn releases/v2 current` is **NOT atomic** on Linux!

---

## 2. The Solution: Kernel-Level `rename(2)` via `mv -T`
In the Linux kernel VFS subsystem, the **`rename()`** system call is **atomic**.
There is never an instant where the destination name fails to exist: any reader process sees either the *old* target or the *new* target.

To atomically swap a symlink:
1. Create a temporary symlink pointing to the new version:
   ```bash
   ln -s "releases/v2" "current.tmp.$$"
   ```
2. Atomically rename the temporary symlink over the active symlink:
   ```bash
   mv -T "current.tmp.$$" "current"
   ```

### Why the `-T` flag matters:
By default, if the destination `current` is a directory or a symlink to a directory, standard `mv file dest` moves `file` *inside* `dest/file`!
The **`-T` (`--no-target-directory`)** flag tells `mv` to treat `current` as a normal file/link and **replace it in-place atomically**.

---

## 3. Recommended Reading List
* `man 1 mv` (Search for: `-T, --no-target-directory`)
* `man 2 rename` (Atomic filesystem replacement semantics)
* Martin Fowler: [BlueGreenDeployment](https://martinfowler.com/bliki/BlueGreenDeployment.html)

---

## 4. Mission Objective
Edit `swap.sh` in your sandbox. Eliminate the non-atomic `rm` command and implement the two-step atomic rename pattern (`ln -s ... current.tmp.$$ && mv -T current.tmp.$$ current`).
Ensure zero 404 errors occur while active readers hit the service.
Verify with `[4] Run State Verification`.
