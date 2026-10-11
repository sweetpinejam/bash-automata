# Structural Scaffolding: Two-Way Dialogue with Bash Coprocesses (`coproc`)

To interactively exchange messages with a challenge-response CLI without external dependencies (`expect`), leverage the Bash built-in `coproc` keyword:

---

## Pattern: Bidirectional Coprocess Protocol

```bash
# 1. Launch a named background coprocess:
coproc AUTH { run_interactive_command; }

# 2. Read from coprocess:
# Index 0 is the read descriptor (Child Stdout -> Shell Input)
read -r challenge <&"${AUTH[0]}"

# 3. Write to coprocess:
# Index 1 is the write descriptor (Shell Output -> Child Stdin)
echo "RESPONSE: $SECRET" >&"${AUTH[1]}"

# 4. Continue conversation:
read -r session_line <&"${AUTH[0]}"
echo "ACK" >&"${AUTH[1]}"

# 5. Read final completion verdict:
read -r verdict <&"${AUTH[0]}"
echo "$verdict"

# 6. Extract token and reap child:
token="${session_line##*: }"
echo "$token" > session.out

# Reclaim coprocess process table entry:
wait "$AUTH_PID"
```

---

## Verifying Coprocess Communication

Confirm session token capture and coprocess exit:
```bash
# Check captured token:
cat session.out

# Confirm coprocess has terminated cleanly (should return non-zero/dead):
kill -0 "$AUTH_PID" 2>/dev/null || echo "Process exited cleanly"
```
