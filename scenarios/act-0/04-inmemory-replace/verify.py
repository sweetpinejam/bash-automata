#!/usr/bin/env python3
"""Fast state-driven verification for Drill 0.04: Pure In-Memory Replace."""
import json
import os
import re
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
    raw_file = workspace / "events.raw"
    sanitized_file = workspace / "events.sanitized"
    metrics_file = workspace / "audit_metrics.json"

    if not script.exists():
        fail("Missing required script: sanitizer.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"sanitizer.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit: strictly no external tools for string manipulation
    log("Auditing pure shell in-memory string replacement in sanitizer.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    for banned in ["sed", "awk", "cut", "perl", "python", "tr"]:
        if re.search(r"\b" + re.escape(banned) + r"\b", active_code):
            fail(f"Prohibited external command '{banned}' detected. Use native parameter expansions (${{VAR//...}}).")

    if "//" not in active_code:
        fail("Missing in-memory pattern replacement syntax (${line//.../...}).")

    # Run sanitizer.sh
    log("Executing pure in-memory stream sanitizer...")
    res = subprocess.run(
        ["bash", str(script), str(raw_file), str(sanitized_file)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"sanitizer.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "SANITIZATION_COMPLETE:" not in res.stdout:
        fail("sanitizer.sh did not emit expected 'SANITIZATION_COMPLETE:' summary.")

    if not sanitized_file.exists():
        fail("Sanitized output file 'events.sanitized' was not created.")

    # Validate sanitized contents
    log("Verifying scrubbed log contents...")
    lines = sanitized_file.read_text(encoding="utf-8").splitlines()
    if len(lines) != 7:
        fail(f"Expected 7 sanitized lines (including non-newline EOF line), found {len(lines)}.")

    full_text = "\n".join(lines)
    if "dev.internal" in full_text:
        fail("Security leak: 'dev.internal' was not completely replaced.")
    if "prod.external" not in full_text:
        fail("Domain substitution failed: 'prod.external' not found.")
    if "SECRET_" in full_text:
        fail("Security leak: 'SECRET_' was not completely replaced.")
    if "REDACTED_" not in full_text:
        fail("Token redaction failed: 'REDACTED_' not found.")
    if "?session=" in full_text:
        fail("Suffix scrubbing failed: '?session=' query parameter was not stripped.")

    # Check prefix replacement
    prefix_trace = [l for l in lines if l.startswith("[TRACE]:")]
    if len(prefix_trace) != 2:
        fail(f"Expected 2 lines with '[TRACE]:' prefix replacement, found {len(prefix_trace)}.")

    # Check final line was preserved and transformed
    if not any("sweep task completed token=REDACTED_9999" in l for l in lines):
        fail("Stream read error: Final line without trailing newline was dropped or corrupted.")

    # Validate audit_metrics.json
    log("Verifying audit_metrics.json...")
    if not metrics_file.exists():
        fail("Missing required 'audit_metrics.json' file.")

    try:
        metrics = json.loads(metrics_file.read_text(encoding="utf-8"))
    except Exception as e:
        fail(f"Invalid JSON in audit_metrics.json: {e}")

    if metrics.get("status") != "SANITIZED":
        fail(f"Expected status 'SANITIZED', got: {metrics.get('status')}")
    if metrics.get("total_lines") != 7:
        fail(f"Expected total_lines=7, got: {metrics.get('total_lines')}")
    if metrics.get("lines_modified") != 6:
        fail(f"Expected lines_modified=6, got: {metrics.get('lines_modified')}")

    log("Successfully verified in-memory stream replacement, EOF safety, and audit JSON metrics!")
    print("\n  [PASS] PURE IN-MEMORY STREAM SANITIZATION FULLY VERIFIED.")


if __name__ == "__main__":
    main()
