#!/usr/bin/env python3
"""Fast state-driven verification for Lesson 0.02: Default Fallbacks & Guards."""
import os
import subprocess
import sys
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def parse_env_file(env_path: Path) -> dict:
    if not env_path.exists():
        return {}
    res = {}
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            res[k.strip()] = v.strip()
    return res


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "env_injector.sh"
    env_file = workspace / ".env"

    if not script.exists():
        fail("Missing required script: env_injector.sh")

    content = script.read_text(encoding="utf-8")
    active_code = "\n".join([l for l in content.splitlines() if not l.strip().startswith("#")])

    # 1. Static parameter expansion audit
    log("Auditing parameter expansions in env_injector.sh...")
    if ":-" not in active_code:
        fail("Missing default fallback operator ':-' (e.g. ${PORT:-8080})")
    if ":?" not in active_code:
        fail("Missing mandatory guard operator ':?' (e.g. ${API_SECRET:?API_SECRET is required})")

    # 2. Test missing mandatory variable (should fail)
    log("Testing security guard: executing with API_SECRET unset...")
    env_empty = {k: v for k, v in os.environ.items() if k not in ("PORT", "DB_HOST", "API_SECRET")}
    res_fail = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        env=env_empty,
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res_fail.returncode == 0:
        fail("Script succeeded when API_SECRET was unset! It must fail with non-zero exit code.")
    log("Security guard successfully aborted execution when API_SECRET was missing.")

    # 3. Test default fallbacks
    log("Testing default fallbacks: executing with API_SECRET='sec_999'...")
    if env_file.exists():
        env_file.unlink()

    env_default = dict(env_empty, API_SECRET="sec_999")
    res_def = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        env=env_default,
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res_def.returncode != 0:
        fail(f"Script failed with valid API_SECRET. Stderr: {res_def.stderr.strip()}")

    cfg = parse_env_file(env_file)
    if cfg.get("PORT") != "8080":
        fail(f"Expected default PORT=8080, got '{cfg.get('PORT')}'")
    if cfg.get("DB_HOST") != "localhost":
        fail(f"Expected default DB_HOST=localhost, got '{cfg.get('DB_HOST')}'")
    if cfg.get("API_SECRET") != "sec_999":
        fail(f"Expected API_SECRET=sec_999, got '{cfg.get('API_SECRET')}'")
    log("Default fallbacks (PORT=8080, DB_HOST=localhost) verified.")

    # 4. Test custom overrides
    log("Testing custom overrides: PORT=3000, DB_HOST=db.prod...")
    if env_file.exists():
        env_file.unlink()

    env_custom = dict(env_empty, PORT="3000", DB_HOST="db.prod", API_SECRET="sec_prod_root")
    res_custom = subprocess.run(
        ["bash", str(script)],
        cwd=str(workspace),
        env=env_custom,
        capture_output=True,
        text=True,
        timeout=5,
    )
    if res_custom.returncode != 0:
        fail(f"Script failed with custom parameters. Stderr: {res_custom.stderr.strip()}")

    cfg_custom = parse_env_file(env_file)
    if cfg_custom.get("PORT") != "3000":
        fail(f"Expected overridden PORT=3000, got '{cfg_custom.get('PORT')}'")
    if cfg_custom.get("DB_HOST") != "db.prod":
        fail(f"Expected overridden DB_HOST=db.prod, got '{cfg_custom.get('DB_HOST')}'")
    if cfg_custom.get("API_SECRET") != "sec_prod_root":
        fail(f"Expected API_SECRET=sec_prod_root, got '{cfg_custom.get('API_SECRET')}'")
    log("Custom overrides properly preserved.")

    print("\n  [PASS] ALL PARAMETER GUARDS & DEFAULTS VERIFIED SUCCESSFULLY.")
    sys.exit(0)


if __name__ == "__main__":
    main()
