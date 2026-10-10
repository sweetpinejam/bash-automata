#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.20: Heredoc Template Forge."""
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
    script = workspace / "forge.sh"
    service_file = workspace / "service.conf"
    run_file = workspace / "run.sh"

    if not script.exists():
        fail("Missing required script: forge.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static audit
    log("Auditing Heredoc declarations in forge.sh...")
    if "<<" not in active_code:
        fail("Missing Heredoc operator '<<'")

    # 2. Execution
    log("Running configuration forge...")
    res = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res.returncode != 0:
        fail(f"forge.sh failed with exit code {res.returncode}. Stderr: {res.stderr.strip()}")

    if "FORGE_COMPLETE" not in res.stdout:
        fail("forge.sh did not complete cleanly.")

    # 3. File validation: service.conf
    log("Validating service.conf variables and directives...")
    if not service_file.exists():
        fail("Generated 'service.conf' is missing.")

    conf_text = service_file.read_text(encoding="utf-8")
    if "Description=telemetry-collector" not in conf_text:
        fail("APP_NAME was not interpolated into service.conf")
    if "Environment=PORT=9090" not in conf_text:
        fail("PORT was not interpolated into service.conf")

    if "ExecReload=/bin/kill -HUP $MAINPID" not in conf_text:
        if "ExecReload=/bin/kill -HUP " in conf_text:
            fail("$MAINPID expanded into an empty string! Escape it in unquoted heredoc: '\\$MAINPID'.")
        else:
            fail("Missing expected ExecReload directive with literal $MAINPID.")

    # 4. File validation: run.sh
    log("Validating run.sh script generation...")
    if not run_file.exists():
        fail("Generated 'run.sh' is missing.")

    run_text = run_file.read_text(encoding="utf-8")
    if "target: $1" not in run_text:
        if "target: " in run_text:
            fail("Literal '$1' was expanded into an empty string! Use a quoted heredoc: 'cat <<'EOF' > run.sh'.")
        else:
            fail("Missing target echo directive in run.sh.")

    if not os.access(run_file, os.X_OK):
        fail("Generated 'run.sh' is not executable.")

    log("Verified variable interpolation, escaped systemd tokens, and literal quoted heredoc.")
    print("\n  [PASS] HEREDOC TEMPLATING FORGE VERIFIED WITH 100% PRECISION.")
    sys.exit(0)


if __name__ == "__main__":
    main()
