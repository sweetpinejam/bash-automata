"""System diagnostic probe ('automata doctor') for environment verification."""
from __future__ import annotations

import os
import platform
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple

from core.engine.state import StateManager
from core.ui.terminal import Colors, UI


class Doctor:
    """Performs deep diagnostic auditing of local host, cgroups, runtimes, and tooling."""

    def __init__(self) -> None:
        self.results: List[Tuple[str, bool, str, str]] = []

    def check_python(self) -> None:
        major, minor = sys.version_info.major, sys.version_info.minor
        ver_str = f"{major}.{minor}.{sys.version_info.micro}"
        if major == 3 and minor >= 12:
            self.results.append(("Python 3.12+ Standard Library", True, f"Python {ver_str}", ""))
        else:
            self.results.append(
                (
                    "Python 3.12+ Standard Library",
                    False,
                    f"Python {ver_str}",
                    "Python 3.12 or newer is required.",
                )
            )

    def check_os(self) -> None:
        os_name = platform.system()
        kernel = platform.release()
        if os_name == "Linux":
            self.results.append(("Linux POSIX Environment", True, f"{os_name} (Kernel {kernel})", ""))
        else:
            self.results.append(
                (
                    "Linux POSIX Environment",
                    False,
                    f"{os_name}",
                    "POSIX Linux is recommended for native process supervision & cgroups.",
                )
            )

    def check_cgroups_v2(self) -> None:
        cgroup_path = Path("/sys/fs/cgroup/cgroup.controllers")
        if cgroup_path.exists():
            try:
                controllers = cgroup_path.read_text().strip()
                self.results.append(
                    ("Linux cgroups v2 Unified Hierarchy", True, f"Controllers: {controllers}", "")
                )
            except Exception as e:
                self.results.append(
                    ("Linux cgroups v2 Unified Hierarchy", True, "Mounted (Read restricted)", "")
                )
        else:
            self.results.append(
                (
                    "Linux cgroups v2 Unified Hierarchy",
                    False,
                    "Not detected",
                    "cgroups v2 not mounted at /sys/fs/cgroup. (Check systemd configuration)",
                )
            )

    def check_docker(self) -> None:
        docker_bin = shutil.which("docker")
        if not docker_bin:
            self.results.append(
                ("Docker Container Engine", False, "Binary not found", "Install docker.io or podman-docker.")
            )
            return

        # Check socket access
        try:
            res = subprocess.run(["docker", "ps"], capture_output=True, text=True, timeout=3)
            if res.returncode == 0:
                self.results.append(
                    ("Docker Container Engine", True, "Daemon connected & responsive", "")
                )
            else:
                hint = "User not in docker group. Run: sudo usermod -aG docker $USER && newgrp docker"
                self.results.append(
                    ("Docker Container Engine", False, "Permission denied on /var/run/docker.sock", hint)
                )
        except Exception as e:
            self.results.append(
                ("Docker Container Engine", False, f"Error: {e}", "Ensure docker service is running.")
            )

    def check_shellcheck(self) -> None:
        sc_bin = shutil.which("shellcheck")
        if sc_bin:
            self.results.append(("ShellCheck Static Linter", True, f"Found at {sc_bin}", ""))
        else:
            self.results.append(
                (
                    "ShellCheck Static Linter",
                    False,
                    "Not installed",
                    "Recommended for defensive script audits. Run: sudo apt install shellcheck",
                )
            )

    def check_git_and_gh(self) -> None:
        git_bin = shutil.which("git")
        gh_bin = shutil.which("gh")

        if not git_bin:
            self.results.append(("Git Version Control", False, "Not found", "Install git."))
        else:
            self.results.append(("Git Version Control", True, f"Found at {git_bin}", ""))

        if not gh_bin:
            self.results.append(
                ("GitHub CLI (gh)", False, "Not installed", "Install gh CLI to push and manage issues.")
            )
        else:
            try:
                res = subprocess.run(["gh", "auth", "status"], capture_output=True, text=True, timeout=4)
                if res.returncode == 0:
                    self.results.append(("GitHub CLI (gh)", True, "Authenticated", ""))
                else:
                    self.results.append(
                        ("GitHub CLI (gh)", False, "Unauthenticated", "Run: gh auth login")
                    )
            except Exception:
                self.results.append(("GitHub CLI (gh)", False, "Error probing gh CLI", ""))

    def check_state_db(self) -> None:
        try:
            sm = StateManager()
            summary = sm.get_summary()
            self.results.append(
                (
                    "SQLite Progress Ledger",
                    True,
                    f"Operational ({sm.db_path})",
                    "",
                )
            )
        except Exception as e:
            self.results.append(
                ("SQLite Progress Ledger", False, f"Failed: {e}", "Check ~/.automata permissions.")
            )

    def run_all(self) -> bool:
        UI.heading("Automata Diagnostic Probe")

        self.check_python()
        self.check_os()
        self.check_cgroups_v2()
        self.check_docker()
        self.check_shellcheck()
        self.check_git_and_gh()
        self.check_state_db()

        headers = ["SUBSYSTEM / TOOL", "STATUS", "DIAGNOSTIC INTEL", "ACTION REQUIRED"]
        rows: List[List[str]] = []

        all_ok = True
        for name, ok, intel, action in self.results:
            status_badge = (
                UI.colorize("[PASS]", Colors.BRIGHT_GREEN, Colors.BOLD)
                if ok
                else UI.colorize("[WARN]", Colors.BRIGHT_YELLOW, Colors.BOLD)
            )
            if not ok and "Python" in name:
                status_badge = UI.colorize("[FAIL]", Colors.BRIGHT_RED, Colors.BOLD)
                all_ok = False

            rows.append([name, status_badge, intel, action or "-"])

        UI.table(headers, rows)

        if all_ok:
            UI.success("Core host environment is primed for scenario execution.")
        else:
            UI.warning("Some auxiliary components require attention (see Action column above).")

        return all_ok
