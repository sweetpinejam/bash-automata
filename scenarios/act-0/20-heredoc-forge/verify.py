#!/usr/bin/env python3
"""State-driven verification for Drill 0.20: Heredoc Template Forge."""
import json
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
    proxy_file = workspace / "proxy.conf"
    run_file = workspace / "run.sh"
    manifest_file = workspace / "forge_manifest.json"

    if not script.exists():
        fail("Missing required script: forge.sh")

    content = script.read_text(encoding="utf-8")
    code_lines = [l for l in content.splitlines() if not l.strip().startswith("#")]
    active_code = "\n".join(code_lines)

    log("Auditing static Heredoc modalities in forge.sh...")
    if "<<" not in active_code:
        fail("Missing Heredoc operator '<<' in forge.sh.")
    if "<<-" not in active_code:
        fail("Missing tab-stripping Heredoc operator '<<-' in forge.sh.")
    if "<<'EOF'" not in active_code and "<<\"EOF\"" not in active_code and "<<'" in active_code:
        fail("Missing literal quoted Heredoc operator '<<'EOF'' in forge.sh.")

    # Clean up previous artifacts
    service_file.unlink(missing_ok=True)
    proxy_file.unlink(missing_ok=True)
    run_file.unlink(missing_ok=True)
    manifest_file.unlink(missing_ok=True)

    log("Executing configuration forge (APP_NAME=custom-agent, PORT=7070)...")
    res = subprocess.run(
        ["bash", str(script), "custom-agent", "7070"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=10,
    )

    if res.returncode != 0:
        fail(f"forge.sh failed with exit code {res.returncode}. Stderr:\n{res.stderr}")

    if "FORGE_COMPLETE" not in res.stdout:
        fail("Expected summary log output starting with 'FORGE_COMPLETE:'.")

    # -------------------------------------------------------------------------
    # 1. Validation: service.conf (Unquoted Heredoc with Escaped $MAINPID)
    # -------------------------------------------------------------------------
    log("Validating service.conf variables and directives...")
    if not service_file.exists():
        fail("Generated 'service.conf' is missing.")

    conf_text = service_file.read_text(encoding="utf-8")
    if "Description=custom-agent Service" not in conf_text:
        fail("APP_NAME was not interpolated into service.conf.")
    if "Environment=PORT=7070" not in conf_text or "--port=7070" not in conf_text:
        fail("PORT was not interpolated into service.conf.")

    if "ExecReload=/bin/kill -HUP $MAINPID" not in conf_text:
        if "ExecReload=/bin/kill -HUP " in conf_text:
            fail("$MAINPID expanded into an empty string! Escape it in unquoted heredoc: '\\$MAINPID'.")
        else:
            fail("Missing expected ExecReload directive with literal $MAINPID.")

    # -------------------------------------------------------------------------
    # 2. Validation: proxy.conf (Tab-Stripped Heredoc <<-EOF)
    # -------------------------------------------------------------------------
    log("Validating proxy.conf tab stripping and directives...")
    if not proxy_file.exists():
        fail("Generated 'proxy.conf' is missing.")

    proxy_text = proxy_file.read_text(encoding="utf-8")
    proxy_lines = [l for l in proxy_text.splitlines() if l.strip()]

    if not proxy_lines:
        fail("Generated 'proxy.conf' is empty.")

    if proxy_lines[0].startswith("\t"):
        fail("Leading tab character was not stripped from proxy.conf! Use 'cat <<-EOF' with hard tabs.")

    if "proxy_pass http://127.0.0.1:7070;" not in proxy_text:
        fail("PORT was not interpolated into proxy.conf proxy_pass directive.")

    # -------------------------------------------------------------------------
    # 3. Validation: run.sh (Quoted Literal Heredoc <<'EOF')
    # -------------------------------------------------------------------------
    log("Validating run.sh script generation and literal parameter retention...")
    if not run_file.exists():
        fail("Generated 'run.sh' is missing.")

    if not os.access(run_file, os.X_OK):
        fail("Generated 'run.sh' is not executable (missing chmod +x).")

    run_text = run_file.read_text(encoding="utf-8")
    if "$1" not in run_text:
        fail("Literal '$1' was expanded into an empty string! Use quoted heredoc '<<'EOF''.")
    if "$@" not in run_text:
        fail("Literal '$@' was expanded into an empty string! Use quoted heredoc '<<'EOF''.")

    # Test executing generated run.sh
    res_run = subprocess.run(
        ["bash", str(run_file), "audit-target", "arg1", "arg2"],
        cwd=str(workspace),
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res_run.returncode != 0:
        fail(f"Generated run.sh failed to execute cleanly: {res_run.stderr}")
    if "Executing agent for target: audit-target" not in res_run.stdout:
        fail("Generated run.sh did not accept positional parameter $1.")

    # -------------------------------------------------------------------------
    # 4. Validation: forge_manifest.json
    # -------------------------------------------------------------------------
    log("Validating forge_manifest.json...")
    if not manifest_file.exists():
        fail("Missing required manifest file: forge_manifest.json.")

    try:
        manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
        if manifest.get("status") != "SUCCESS":
            fail(f"Expected status 'SUCCESS' in manifest, got: {manifest.get('status')}")
        if manifest.get("app_name") != "custom-agent":
            fail(f"Expected app_name 'custom-agent', got: {manifest.get('app_name')}")
        if manifest.get("port") != 7070:
            fail(f"Expected port 7070, got: {manifest.get('port')}")
        artifacts = manifest.get("artifacts", [])
        if len(artifacts) != 3:
            fail(f"Expected 3 artifacts cataloged in manifest, got: {len(artifacts)}")
        for art in artifacts:
            if art.get("size", 0) <= 0:
                fail(f"Artifact {art.get('name')} has invalid size: {art.get('size')}")
    except json.JSONDecodeError as exc:
        fail(f"Failed to parse forge_manifest.json as JSON: {exc}")

    log("Verified unquoted interpolation, escaped systemd tokens, tab-stripping, and quoted script generation!")
    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
