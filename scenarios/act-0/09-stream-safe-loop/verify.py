#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.09: Stream-Safe While Loops."""
import os
import subprocess
import sys
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "compiler.sh"
    tmpl_file = workspace / "template.conf"
    final_file = workspace / "final.conf"

    if not script.exists():
        fail("Missing required script: compiler.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing stream-safe while loop idioms in compiler.sh...")
    if "for " in active_code and "cat " in active_code:
        fail("Prohibited 'for ... in $(cat ...)' detected. Replace with 'while IFS= read -r line'.")

    if "while " not in active_code or "read " not in active_code:
        fail("Missing 'while ... read ...' loop.")

    if "IFS=" not in active_code:
        fail("Missing 'IFS=' prefix on read loop (required to preserve whitespace indentation).")

    if "-r" not in active_code:
        fail("Missing '-r' flag on read command (required to preserve literal backslashes).")

    # 2. Execution
    log("Running configuration compiler...")
    res = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"compiler.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "COMPILATION_COMPLETE" not in res.stdout:
        fail("compiler.sh did not complete cleanly.")

    # 3. Content fidelity check
    log("Validating byte-for-byte fidelity of compiled config...")
    if not final_file.exists():
        fail("Output file 'final.conf' was not created.")

    expected = tmpl_file.read_text(encoding="utf-8")
    actual = final_file.read_text(encoding="utf-8")

    if expected != actual:
        fail("Indentation, whitespace, or backslashes were altered or stripped in final.conf!")

    log("Verified exact whitespace indentation and regex backslashes preserved.")
    print("\n  [PASS] STREAM-SAFE WHILE LOOP IDIOM VERIFIED WITH 100% BYTE FIDELITY.")
    sys.exit(0)


if __name__ == "__main__":
    main()
