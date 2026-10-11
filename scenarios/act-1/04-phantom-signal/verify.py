#!/usr/bin/env python3
"""Fast state-driven verification for Mission 1.04: The Phantom Signal."""
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


def is_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def main():
    workspace = Path(os.environ.get("AUTOMATA_WORKSPACE", "."))
    script = workspace / "proxy.sh"
    conf_file = workspace / "app.conf"
    pid_file = workspace / "proxy.pid"
    log_file = workspace / "proxy.log"
    metrics_file = workspace / "metrics.dump"

    if not script.exists():
        fail("Missing required script: proxy.sh")

    # Clean previous artifacts
    for f in [pid_file, log_file, metrics_file]:
        if f.exists():
            f.unlink()

    # Reset initial config
    conf_file.write_text('BACKEND="10.0.0.1:8080"\nTIMEOUT="30"\n', encoding="utf-8")

    # 1. Start daemon
    log("Booting proxy daemon...")
    proc = subprocess.Popen(
        ["bash", str(script)],
        cwd=str(workspace),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    try:
        # Wait up to 1.0s for pid_file
        deadline = time.time() + 1.0
        pid = None
        while time.time() < deadline:
            if pid_file.exists() and pid_file.read_text().strip():
                pid = int(pid_file.read_text().strip())
                break
            time.sleep(0.05)

        if not pid or not is_running(pid):
            fail("Proxy daemon failed to boot or did not write proxy.pid.")

        log(f"Proxy daemon running at PID {pid}.")

        # 2. Inject hot config change & SIGHUP
        log("Updating app.conf and sending SIGHUP (hot-reload signal)...")
        conf_file.write_text('BACKEND="10.0.0.99:9000"\nTIMEOUT="60"\n', encoding="utf-8")
        os.kill(pid, signal.SIGHUP)
        time.sleep(0.2)

        if not is_running(pid):
            fail("DAEMON CRASHED: Proxy daemon exited upon receiving SIGHUP! SIGHUP was untrapped.")

        # Check proxy.log for reload notice
        log_text = log_file.read_text(encoding="utf-8") if log_file.exists() else ""
        if "CONFIG_RELOADED" not in log_text or "10.0.0.99:9000" not in log_text:
            fail("SIGHUP did not reload configuration or write 'CONFIG_RELOADED' to proxy.log.")
        log("SIGHUP hot-reload verified: updated backend to 10.0.0.99:9000 without downtime.")

        # 3. Send SIGUSR1 for metrics dump
        log("Sending SIGUSR1 (telemetry dump signal)...")
        os.kill(pid, signal.SIGUSR1)
        time.sleep(0.2)

        if not metrics_file.exists():
            fail("SIGUSR1 did not produce 'metrics.dump'.")

        m_text = metrics_file.read_text(encoding="utf-8")
        if "10.0.0.99:9000" not in m_text:
            fail(f"metrics.dump contains outdated or invalid stats: '{m_text}'")
        log(f"SIGUSR1 telemetry dump verified: '{m_text.strip()}'.")

    finally:
        # 4. Graceful shutdown via SIGTERM
        if pid and is_running(pid):
            os.kill(pid, signal.SIGTERM)
            try:
                proc.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                os.kill(pid, signal.SIGKILL)

    print("\n  [PASS] UNIX SIGNAL TRAPS (SIGHUP, SIGUSR1, SIGTERM) FULLY VERIFIED.")
    sys.exit(0)


if __name__ == "__main__":
    main()
