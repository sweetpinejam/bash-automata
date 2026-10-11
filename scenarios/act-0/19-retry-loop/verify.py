#!/usr/bin/env python3
"""State-driven verification for Drill 0.19: The Exponential Backoff Retry Loop."""
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path


def log(msg: str):
    print(f"  [VERIFY] {msg}")


def fail(msg: str):
    print(f"  [FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def ensure_daemon(workspace: Path) -> int:
    port_file = workspace / "daemon_port.txt"
    pid_file = workspace / "daemon.pid"

    # Check if existing daemon is alive
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text(encoding="utf-8").strip())
            os.kill(pid, 0)
            if port_file.exists():
                return int(port_file.read_text(encoding="utf-8").strip())
        except (ValueError, OSError):
            pass

    # Start new daemon
    daemon_script = workspace / "health_daemon.py"
    if not daemon_script.exists():
        fail("health_daemon.py not found in workspace.")

    proc = subprocess.Popen(
        [sys.executable, str(daemon_script), "--ready-after", "3", "--port-file", str(port_file)],
        cwd=str(workspace),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    pid_file.write_text(f"{proc.pid}\n", encoding="utf-8")

    for _ in range(20):
        time.sleep(0.1)
        if port_file.exists():
            try:
                return int(port_file.read_text(encoding="utf-8").strip())
            except ValueError:
                pass
    fail("Failed to initialize local health daemon on ephemeral port.")


def cleanup_daemon(workspace: Path):
    pid_file = workspace / "daemon.pid"
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text(encoding="utf-8").strip())
            os.kill(pid, signal.SIGTERM)
        except (ValueError, OSError):
            pass
        pid_file.unlink(missing_ok=True)
    (workspace / "daemon_port.txt").unlink(missing_ok=True)


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    probe_sh = workspace / "probe.sh"
    log_file = workspace / "probe_attempts.log"
    summary_file = workspace / "probe_summary.json"

    if not probe_sh.exists():
        fail("Missing required script: probe.sh")

    content = probe_sh.read_text(encoding="utf-8")
    code_lines = [l for l in content.splitlines() if not l.strip().startswith("#")]
    active_code = "\n".join(code_lines)

    log("Auditing exponential backoff structure in probe.sh...")
    if "while " not in active_code and "for " not in active_code:
        fail("probe.sh must implement a polling loop using 'while' or 'for'.")
    if "curl" not in active_code:
        fail("probe.sh must query the target endpoint using 'curl'.")
    if "mock_service.sh" in active_code:
        fail("Toy mock 'mock_service.sh' prohibited. Query real services with curl.")
    if "delay" not in active_code:
        fail("probe.sh must manage a 'delay' backoff variable.")

    try:
        # ---------------------------------------------------------------------
        # Test 1: Successful Probe Against Warming-Up Microservice
        # ---------------------------------------------------------------------
        log("Test 1: Probing warming-up microservice (ready on attempt 3)...")
        # Ensure fresh daemon
        cleanup_daemon(workspace)
        port = ensure_daemon(workspace)
        target_url = f"http://127.0.0.1:{port}/health"

        log_file.unlink(missing_ok=True)
        summary_file.unlink(missing_ok=True)

        res1 = subprocess.run(
            ["bash", str(probe_sh), target_url, "5"],
            cwd=str(workspace),
            capture_output=True,
            text=True,
            timeout=15,
        )

        if res1.returncode != 0:
            fail(f"probe.sh failed on warming-up service ({res1.returncode}). Stderr:\n{res1.stderr}")

        if "PROBE_SUCCESS" not in res1.stdout:
            fail("Expected 'PROBE_SUCCESS:' summary output on successful probe.")

        if not summary_file.exists():
            fail("probe.sh did not produce 'probe_summary.json'.")

        try:
            summary = json.loads(summary_file.read_text(encoding="utf-8"))
            if summary.get("status") != "SERVICE_READY":
                fail(f"Expected status 'SERVICE_READY', got: {summary.get('status')}")
            if summary.get("total_attempts") != 3:
                fail(f"Expected 3 attempts for warming-up service, got: {summary.get('total_attempts')}")
        except json.JSONDecodeError as exc:
            fail(f"Failed to parse probe_summary.json as JSON: {exc}")

        if not log_file.exists():
            fail("probe.sh did not generate 'probe_attempts.log'.")

        attempts = [l for l in log_file.read_text(encoding="utf-8").splitlines() if l.strip()]
        if len(attempts) != 3:
            fail(f"Expected exactly 3 logged attempts in probe_attempts.log, got: {len(attempts)}")

        log("Successfully survived warm-up phase and reached SERVICE_READY on attempt 3.")

        # ---------------------------------------------------------------------
        # Test 2: Timeout Against Permanently Dead Service
        # ---------------------------------------------------------------------
        log("Test 2: Stress testing timeout exhaustion against dead endpoint...")
        log_file.unlink(missing_ok=True)
        summary_file.unlink(missing_ok=True)

        env = dict(os.environ)
        env["BASE_DELAY"] = "0"
        env["MAX_DELAY"] = "0"

        res2 = subprocess.run(
            ["bash", str(probe_sh), "http://127.0.0.1:19999/nonexistent", "3"],
            cwd=str(workspace),
            env=env,
            capture_output=True,
            text=True,
            timeout=10,
        )

        if res2.returncode == 0:
            fail("probe.sh unexpectedly succeeded against a non-existent port!")

        combined2 = res2.stdout + res2.stderr
        if "PROBE_TIMEOUT" not in combined2:
            fail(f"Expected 'PROBE_TIMEOUT' error output upon attempt exhaustion. Got:\n{combined2}")

        if not summary_file.exists():
            fail("probe.sh did not generate 'probe_summary.json' upon timeout exhaustion.")

        try:
            summary2 = json.loads(summary_file.read_text(encoding="utf-8"))
            if summary2.get("status") != "TIMEOUT":
                fail(f"Expected status 'TIMEOUT' in summary, got: {summary2.get('status')}")
            if summary2.get("total_attempts") != 3:
                fail(f"Expected 3 attempts on timeout, got: {summary2.get('total_attempts')}")
        except json.JSONDecodeError as exc:
            fail(f"Failed to parse timeout probe_summary.json: {exc}")

        log("Timeout exhaustion, attempt capping, and failure manifest verified.")

    finally:
        cleanup_daemon(workspace)

    print("ALL STATE ASSERTIONS PASSED")
    sys.exit(0)


if __name__ == "__main__":
    main()
