#!/usr/bin/env python3
"""State assertion test for Mission 2.07: The Two-Way Coprocess Dialogue."""
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
    bot_sh = workspace / "auth_bot.sh"
    session_file = workspace / "session.out"

    if not bot_sh.exists():
        fail("Missing required script: auth_bot.sh")

    if session_file.exists():
        session_file.unlink()

    log("Executing auth_bot interactive handshake...")
    try:
        proc = subprocess.run(
            ["bash", str(bot_sh)],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=5,
        )
    except subprocess.TimeoutExpired:
        fail("auth_bot.sh timed out (>5s) — possible deadlock on standard streams!")
    except Exception as e:
        fail(f"Execution error: {e}")

    if proc.returncode != 0:
        fail(f"auth_bot.sh failed with exit code {proc.returncode}.\nStderr: {proc.stderr.strip()}\nStdout: {proc.stdout.strip()}")

    if "AUTH_SUCCESS" not in proc.stdout:
        fail("auth_bot.sh did not receive or emit 'AUTH_SUCCESS'.")

    log("Auditing session token capture in session.out...")
    if not session_file.exists():
        fail("session.out was not generated!")

    content = session_file.read_text(encoding="utf-8").strip()
    log(f"Session token captured: '{content}'")

    if "sess_vault_998877" not in content:
        fail(f"Invalid session token! Expected 'sess_vault_998877', found: '{content}'")

    log("ALL TWO-WAY COPROCESS ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
