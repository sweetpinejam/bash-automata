# Code Blueprint: Two-Way Dialogue with Bash Coprocesses (`coproc`)

Interact bidirectionally with an interactive CLI using Bash's built-in `coproc`:

```bash
# Blueprint Pattern:
# Launch coprocess named AUTH:
coproc AUTH { python3 security_cli.py; }

# Read from coprocess (stdout of coprocess is on FD ${AUTH[0]}):
read -r challenge <&"${AUTH[0]}"

# Write to coprocess (stdin of coprocess is on FD ${AUTH[1]}):
echo "RESPONSE: $SECRET" >&"${AUTH[1]}"

# Continue dialogue:
read -r session_line <&"${AUTH[0]}"
echo "ACK" >&"${AUTH[1]}"

read -r final_verdict <&"${AUTH[0]}"
echo "$final_verdict"

# Extract session token:
session_id="${session_line##*: }"
echo "$session_id" > session.out

# Wait for coprocess termination:
wait "$AUTH_PID"
```

> **Key Rule**:
> - `${NAME[0]}`: Read descriptor (coprocess stdout ➔ shell input)
> - `${NAME[1]}`: Write descriptor (shell output ➔ coprocess stdin)
> - `$NAME_PID`: Automatically populated with the background coprocess PID.
