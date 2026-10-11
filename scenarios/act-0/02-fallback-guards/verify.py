#!/usr/bin/env python3
"""State-driven verification harness for Drill 0.02: Default Fallbacks & Guards."""
import os
import stat
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
    script = workspace / "env_injector.sh"

    if not script.exists():
        fail("Missing required script: env_injector.sh")

    # Static syntax check
    res_syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    if res_syntax.returncode != 0:
        fail(f"env_injector.sh has syntax errors: {res_syntax.stderr.strip()}")

    # Test 1: Missing API_SECRET guardrail
    log("Testing mandatory API_SECRET assertion...")
    env_no_secret = {"PATH": os.environ.get("PATH", "")}
    res1 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        env=env_no_secret,
        capture_output=True,
        text=True,
    )
    if res1.returncode == 0:
        fail("env_injector.sh must exit non-zero when API_SECRET is missing.")
    if "API_SECRET is required" not in res1.stderr and "API_SECRET" not in res1.stderr:
        fail(f"Expected API_SECRET guard error message on stderr. Got: {res1.stderr.strip()}")

    # Test 2: Missing CLUSTER_NAME guardrail
    log("Testing mandatory CLUSTER_NAME assertion...")
    env_no_cluster = {"PATH": os.environ.get("PATH", ""), "API_SECRET": "sec123"}
    res2 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        env=env_no_cluster,
        capture_output=True,
        text=True,
    )
    if res2.returncode == 0:
        fail("env_injector.sh must exit non-zero when CLUSTER_NAME is missing.")

    # Test 3: Invalid Port Validation
    log("Testing port range validation (PORT=99999)...")
    env_bad_port = {
        "PATH": os.environ.get("PATH", ""),
        "API_SECRET": "sec123",
        "CLUSTER_NAME": "prod-1",
        "PORT": "99999",
    }
    res3 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        env=env_bad_port,
        capture_output=True,
        text=True,
    )
    if res3.returncode == 0:
        fail("env_injector.sh must exit non-zero when PORT exceeds 65535.")

    # Test 4: Default Fallbacks & Secret Redaction
    log("Testing default fallbacks and secret masking in logs...")
    env_defaults = {
        "PATH": os.environ.get("PATH", ""),
        "API_SECRET": "super_secret_token_99",
        "CLUSTER_NAME": "us-west-prod",
    }
    res4 = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        env=env_defaults,
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res4.returncode != 0:
        fail(f"env_injector.sh failed with defaults: {res4.stderr.strip()}")

    if "super_secret_token_99" in res4.stdout:
        fail("Security breach: Unmasked secret found in console output!")
    if "***REDACTED***" not in res4.stdout:
        fail("Console output did not mask API_SECRET as '***REDACTED***'.")
    if "CONFIG_COMPILED:" not in res4.stdout:
        fail("Missing summary line 'CONFIG_COMPILED:' in stdout.")

    runtime_env = workspace / ".env.runtime"
    if not runtime_env.exists():
        fail("Compiled config file '.env.runtime' was not created.")

    # Check file permissions (should be 0600)
    file_mode = stat.S_IMODE(runtime_env.stat().st_mode)
    if file_mode != 0o600:
        fail(f"Expected file permissions 0600 on .env.runtime, found: {oct(file_mode)}")

    cfg_text = runtime_env.read_text(encoding="utf-8")
    expected_pairs = [
        "PORT=8080",
        "DB_HOST=127.0.0.1",
        "DB_PORT=5432",
        "LOG_LEVEL=INFO",
        "TIMEOUT_SECONDS=30",
        "API_SECRET=super_secret_token_99",
        "CLUSTER_NAME=us-west-prod",
        "METRICS_ENABLED=false",
    ]
    for pair in expected_pairs:
        if pair not in cfg_text:
            fail(f"Missing or incorrect key-value in .env.runtime: '{pair}'")

    # Test 5: Custom Overrides & Alternate Substitution
    log("Testing custom overrides and alternate parameter expansion...")
    custom_out = workspace / ".env.custom"
    env_custom = {
        "PATH": os.environ.get("PATH", ""),
        "API_SECRET": "custom_secret_key",
        "CLUSTER_NAME": "ap-southeast-1",
        "PORT": "3000",
        "PROMETHEUS_ENDPOINT": "http://prometheus.internal:9090",
    }
    res5 = subprocess.run(
        ["bash", str(script), "--output", str(custom_out)],
        cwd=str(workspace),
        env=env_custom,
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res5.returncode != 0:
        fail(f"env_injector.sh failed with custom output: {res5.stderr.strip()}")

    if not custom_out.exists():
        fail(f"Custom output file '{custom_out.name}' was not created.")

    custom_text = custom_out.read_text(encoding="utf-8")
    if "PORT=3000" not in custom_text:
        fail("Custom PORT=3000 was not applied.")
    if "METRICS_ENABLED=true" not in custom_text:
        fail("Alternate expansion failed: METRICS_ENABLED should be true when PROMETHEUS_ENDPOINT is set.")

    log("Successfully verified fallbacks, guardrails, alternate substitutions, and secret permissions!")
    print("\n  [PASS] ALL PARAMETER GUARDS & DEFAULTS VERIFIED SUCCESSFULLY.")


if __name__ == "__main__":
    main()
