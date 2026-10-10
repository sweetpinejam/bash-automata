#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.04: Pure In-Memory Replace."""
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
    script = workspace / "sanitizer.sh"
    out_file = workspace / "events.sanitized"

    if not script.exists():
        fail("Missing required script: sanitizer.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing pure shell pattern substitution in sanitizer.sh...")
    for banned in ["sed", "awk", "perl", "python", "tr"]:
        if banned in active_code:
            fail(f"Prohibited external command '{banned}' detected. Use native '${{VAR//pattern/replacement}}'.")

    if "//" not in active_code:
        fail("Missing parameter pattern replacement operator '//' (e.g. ${line//dev.internal/prod.external})")

    # 2. Execution
    log("Running automated sanitizer...")
    res = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"sanitizer.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "SANITIZATION_COMPLETE" not in res.stdout:
        fail("sanitizer.sh did not complete cleanly.")

    # 3. Validation
    if not out_file.exists():
        fail("Output file 'events.sanitized' was not generated.")

    lines = out_file.read_text(encoding="utf-8").strip().splitlines()
    if len(lines) != 3:
        fail(f"Expected 3 sanitized records, got {len(lines)}")

    for idx, line in enumerate(lines, 1):
        if "dev.internal" in line:
            fail(f"Line {idx} still contains un-sanitized internal domain: '{line}'")
        if "prod.external" not in line:
            fail(f"Line {idx} does not contain expected target domain 'prod.external'")
        if "SECRET_" in line:
            fail(f"Line {idx} still contains un-redacted secret token: '{line}'")
        if "REDACTED_" not in line:
            fail(f"Line {idx} does not contain redacted secret tag 'REDACTED_'")

    log("Verified all domains updated to prod.external and secrets redacted.")
    print("\n  [PASS] ALL RECORDS SANITIZED IN-MEMORY WITHOUT SPAWNING SED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
