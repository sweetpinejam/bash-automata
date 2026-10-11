#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.09: Stream-Safe While Loops."""
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
    script = workspace / "compiler.sh"
    tmpl_file = workspace / "template.conf"
    out_file = workspace / "final.conf"

    if not script.exists():
        fail("Missing required script: compiler.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"compiler.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Static audit for stream-safe loop and absence of broken cat-for loops
    log("Auditing stream-safe loop construction in compiler.sh...")
    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    if re.search(r'for\s+\w+\s+in\s+\$\(cat\b', active_code) or re.search(r'for\s+\w+\s+in\s+\$\(<', active_code):
        fail("Anti-pattern detected: 'for line in $(cat ...)' destroys indentation and word-splits.")

    if "read -r" not in active_code or "IFS=" not in active_code:
        fail("Missing required 'while IFS= read -r line' construct.")

    # Test 1: Full compilation with variable replacements
    log("Testing stream compilation with variable substitutions...")
    res1 = subprocess.run(
        [
            "bash",
            str(script),
            "--var", "PORT=8443",
            "--var", "SERVER_NAME=api.internal",
            "--var", "UPSTREAM=127.0.0.1:3000",
            "--var", "TELEMETRY_STATUS=enabled",
            str(tmpl_file),
            str(out_file),
        ],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res1.returncode != 0:
        fail(f"compiler.sh failed with exit code {res1.returncode}. Stderr: {res1.stderr.strip()}")

    if "COMPILER_SUMMARY:" not in res1.stdout:
        fail("compiler.sh did not emit expected 'COMPILER_SUMMARY:' summary.")

    if not out_file.exists():
        fail("Compiled config file 'final.conf' was not created.")

    lines = out_file.read_text(encoding="utf-8").splitlines()
    if len(lines) != 17:
        fail(f"Expected 17 compiled lines (including un-terminated EOF line), got {len(lines)}.")

    # Indentation & Byte Fidelity Checks
    if "    listen 8443;" not in lines:
        fail("Indentation lost or variable substitution failed: expected '    listen 8443;'.")

    # Regex and Backslash checks
    if r"    location ~* \.(jpg|jpeg|png|css|js)$ {" not in lines:
        fail(r"Backslash escaping corrupted in regex line: expected '    location ~* \.(jpg|jpeg|png|css|js)$ {'.")

    # Check non-newline trailing line
    if "    # Telemetry: enabled" not in lines:
        fail("Final line without trailing newline was dropped or corrupted.")

    # Test 2: Compilation with --strip-comments
    log("Testing compilation with --strip-comments...")
    stripped_file = workspace / "stripped.conf"
    res2 = subprocess.run(
        [
            "bash",
            str(script),
            "--strip-comments",
            "--var", "PORT=80",
            str(tmpl_file),
            str(stripped_file),
        ],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res2.returncode != 0:
        fail(f"compiler.sh failed with --strip-comments: {res2.stderr.strip()}")

    stripped_lines = stripped_file.read_text(encoding="utf-8").splitlines()
    for l in stripped_lines:
        if l.strip().startswith("#"):
            fail(f"Comment line not stripped: '{l}'")

    if len(stripped_lines) != 13:
        fail(f"Expected 13 lines after stripping comments, found {len(stripped_lines)}.")

    log("Successfully verified stream-safe while loops, indentation preservation, and backslash safety!")
    print("\n  [PASS] STREAM-SAFE WHILE LOOP IDIOM VERIFIED WITH 100% BYTE FIDELITY.")


if __name__ == "__main__":
    main()
