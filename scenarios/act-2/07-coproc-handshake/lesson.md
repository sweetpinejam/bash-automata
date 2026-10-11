# Tactical Field Manual: The Two-Way Coprocess Dialogue

> **Incident Class**: Interactive Protocol Negotiation & Deadlock Avoidance  
> **Key Tooling**: `coproc NAME { cmd; }`, `${NAME[0]}`, `${NAME[1]}`, `$NAME_PID`

---

## 1. The Incident: The Limitation of One-Way Pipes

Standard Unix pipelines (`cmd1 | cmd2`) are strictly unidirectional:
- Data only flows forward from `cmd1` stdout to `cmd2` stdin.
- If `cmd2` asks a question, waits for `cmd1` to answer, and then produces another question, a standard pipe immediately hangs in a deadlock.

Automation scripts that interact with challenge-response protocols (like HSM key managers, VPN token decoders, or legacy interactive CLI tools) must be able to **read and write concurrently to the same running process**.

---

## 2. Architecture: Bash Coprocess (`coproc`)

```
   SHELL ENVIRONMENT                             COPROCESS (security_cli.py)
  ┌─────────────────────────────────┐           ┌────────────────────────────┐
  │                                 │           │                            │
  │   read <&"${AUTH[0]}"           │◄── stdout ┤ Issues CHALLENGE           │
  │                                 │           │                            │
  │   echo >&"${AUTH[1]}"           ├──► stdin ─┤ Receives RESPONSE          │
  │                                 │           │                            │
  │   read <&"${AUTH[0]}"           │◄── stdout ┤ Issues SESSION_ID          │
  │                                 │           │                            │
  │   echo "ACK" >&"${AUTH[1]}"     ├──► stdin ─┤ Receives ACK               │
  │                                 │           │                            │
  │   read <&"${AUTH[0]}"           │◄── stdout ┤ Emits AUTH_SUCCESS         │
  └─────────────────────────────────┘           └────────────────────────────┘
```

---

## 3. The `coproc` Command

In Bash, `coproc` spawns an asynchronous process with two connected pipes:
- `${NAME[0]}`: File descriptor connected to the coprocess's standard output.
- `${NAME[1]}`: File descriptor connected to the coprocess's standard input.
- `$NAME_PID`: The process ID of the spawned child.

This provides full bidirectional communication in pure Bash without requiring external tools like `expect`.
