# Tactical Blueprint: Managing File Descriptor Lifecycles (`exec {fd}<&-`)

To prevent process table exhaustion and `EMFILE: Too many open files` errors when allocating custom file descriptors:

---

## 1. Dynamic Allocation and Explicit Closure

```bash
# Allocate dynamic input descriptor (assigned an unused integer >= 10):
exec {fd}< "$path"

# Read from custom descriptor:
read -r payload <&"$fd"

# CRUCIAL: Release the table slot when finished:
exec {fd}<&-
```

---

## 2. Redirection Syntax Breakdown
* `exec {fd}< "$file"`: Asks the kernel to open `$file` for reading and store the resulting descriptor index in variable `$fd`.
* `<&"$fd"`: Redirects the preceding command's standard input to read from the descriptor index stored in `$fd`.
* `exec {fd}<&-`: The minus sign (`-`) closes the descriptor, calling `close(fd)` at the kernel level and recycling the slot in the process table.
