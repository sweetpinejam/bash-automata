# Tactical Field Manual: The Two-Way Coprocess Dialogue (`coproc` & Bidirectional IPC)

> **POSIX & Linux Systems Engineering Handbook**  
> **Subsystem**: Bash Coprocesses (`coproc`), Paired Kernel Pipes, and Full-Duplex Stream Protocols

---

## 1. Architectural Mental Model: Simplex Pipelines vs Full-Duplex Dialogue

In standard Unix architecture, traditional pipelines (`cmd1 | cmd2`) are strictly **simplex (unidirectional)**:
- Bytes flow exclusively from the standard output of `cmd1` into the standard input of `cmd2`.
- There is no reverse data channel.

```
Standard Pipeline (Simplex / One-Way):
[ Process A (stdout) ] ──( Kernel Pipe )──▶ [ Process B (stdin) ]
```

### The Challenge-Response Deadlock
Many enterprise security services, Hardware Security Modules (HSMs), key vaults, database shells, and interactive command-line tools require a multi-turn conversational dialogue:

```
Step 1: Security Daemon issues CHALLENGE
Step 2: Client computes and returns RESPONSE
Step 3: Security Daemon verifies and issues SESSION_ID
Step 4: Client acknowledges ACK
Step 5: Security Daemon grants AUTH_SUCCESS
```

If an automation script attempts to drive this dialogue using a standard pipeline (`echo "RESPONSE" | security_cli`), the interaction fails immediately:
1. The pipeline cannot read the initial challenge before sending its response.
2. The pipeline cannot capture the session token generated after the response.
3. The child terminates prematurely or stalls in an I/O deadlock.

---

## 2. Kernel Primitives: Paired Anonymous Pipes via `coproc`

To conduct a bidirectional dialogue in pure Bash without requiring heavyweight external dependencies like `expect` or Python PTY wrappers, Bash provides the **`coproc`** builtin:

```
               SHELL ENVIRONMENT                                COPROCESS (Child)
  ┌─────────────────────────────────────────┐         ┌───────────────────────────────────┐
  │                                         │         │                                   │
  │  read -r prompt <&"${AUTH[0]}"          │◀────────┼─ stdout (Pipe 2: Child ➔ Parent)  │
  │                                         │         │                                   │
  │  echo "RESPONSE" >&"${AUTH[1]}"         ├─────────┼─▶ stdin (Pipe 1: Parent ➔ Child)  │
  │                                         │         │                                   │
  │  wait "$AUTH_PID"                       │         │                                   │
  └─────────────────────────────────────────┘         └───────────────────────────────────┘
```

### How `coproc` Operates Under the Hood:
1. The shell creates **two distinct anonymous pipes** using the `pipe(2)` system call.
2. The shell forks a child process:
   - The child's `stdin` (FD 0) is bound to the read end of Pipe 1.
   - The child's `stdout` (FD 1) is bound to the write end of Pipe 2.
3. In the parent shell, the opposite ends are exposed as a two-element array variable:
   - **`${NAME[0]}`**: Read descriptor (reading output produced by the coprocess).
   - **`${NAME[1]}`**: Write descriptor (writing input into the coprocess).
   - **`$NAME_PID`**: The process ID of the background child.

---

## 3. Protocol Syntax & Execution Lifecycle

### 1. Spawning a Named Coprocess
```bash
coproc AUTH { python3 security_cli.py; }
```
*Always use a named coprocess (`coproc NAME { ... }`).* If no name is provided, Bash assigns the default name `COPROC`, but only allows a single unnamed coprocess to exist simultaneously.

### 2. Reading from the Coprocess
To read a line from the coprocess stdout:
```bash
read -r challenge <&"${AUTH[0]}"
```
The `<&` operator duplicates input from file descriptor `${AUTH[0]}` into standard input for the `read` command.

### 3. Writing to the Coprocess
To send a message to the coprocess stdin:
```bash
echo "RESPONSE: $SECRET" >&"${AUTH[1]}"
```
The `>&` operator redirects standard output of `echo` into file descriptor `${AUTH[1]}`.

### 4. Reaping the Coprocess
Always collect the coprocess exit status upon dialogue conclusion:
```bash
wait "$AUTH_PID"
```

---

## 4. The Critical Stdio Buffering Deadlock Hazard

The most common failure in coprocess programming is **user-space buffering deadlocks**:
- By default, standard C runtimes switch to **4KB block buffering** when `stdout` is connected to a pipe (`isatty == 0`).
- If the child process issues `printf("CHALLENGE\n")` without calling `fflush(stdout)` (or in Python without `flush=True`), the text remains trapped in the child's `stdio` buffer!
- The parent shell blocks on `read <&"${AUTH[0]}"`, waiting for data that never arrives.
- The child blocks on `read()`, waiting for input from the parent.
- **Both processes freeze permanently in a circular I/O deadlock!**

### Prevention:
Ensure the child program flushes its standard output immediately after each prompt (`flush=True` in Python, or wrap execution with `stdbuf -oL`).

---

## 5. Production Gotchas & Edge Cases

| Hazard | Cause | Prevention / Solution |
| :--- | :--- | :--- |
| **SIGPIPE on Premature Write** | Parent writes to `${AUTH[1]}` after the coprocess has already crashed or exited. | Check if process is alive (`kill -0 "$AUTH_PID"`) or trap `SIGPIPE`. |
| **Unclosed Descriptors** | Leaving `${AUTH[0]}` and `${AUTH[1]}` open after coprocess exit leaks file descriptors. | Close explicitly when finished: `exec {AUTH[0]}<&-` and `exec {AUTH[1]}>&-`. |
| **Single Unnamed Coprocess Limit** | Launching a second unnamed `coproc` destroys the descriptors of the previous one. | Always specify an explicit identifier: `coproc MY_PROC { ...; }`. |

---

## 6. Curated Reading List & Authoritative Manuals

Study these authoritative system documentation sources to master bidirectional coprocesses:

1. **`man 1 bash`**
   - Search for `Coprocesses` to read the complete reference manual on `coproc`, naming rules, and descriptor arrays.
2. **`man 2 pipe`**
   - The Linux Programmer's Manual on anonymous pipe creation, kernel ring buffers, and EOF semantics.
3. **`man 2 socketpair`**
   - The POSIX standard for creating bidirectional full-duplex socket pairs (`AF_UNIX`, `SOCK_STREAM`).
4. **The Linux Programming Interface (TLPI) by Michael Kerrisk**
   - *Chapter 44: Pipes and FIFOs* — Section 44.2 (Creating and Using Pipes) and Section 44.4 (Pipes as a Method of Process Synchronization).
   - *Chapter 54: Interprocess Communication Overview* — Comparing Pipes, FIFOs, Sockets, and Coprocesses.

---

## 7. Self-Assessment Checklist

Test your understanding of Bash coprocesses:
- [ ] Why does an interactive challenge-response handshake fail when executed through a standard pipeline (`|`)?
- [ ] What is the exact difference between `${AUTH[0]}` and `${AUTH[1]}` in a named Bash coprocess?
- [ ] Why does Python's `sys.stdout.flush()` or `flush=True` become strictly mandatory when communicating with a coprocess?
- [ ] What system call does the kernel issue when creating the two underlying data channels for a coprocess?
- [ ] What happens to the parent shell if it attempts to write to `${AUTH[1]}` after the coprocess has terminated?
