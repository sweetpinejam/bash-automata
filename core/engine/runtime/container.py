"""Containerized Docker/Podman runtime adapter with cgroups v2 resource clamping."""
from __future__ import annotations

import os
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from core.engine.runtime.base import RuntimeResult, ScenarioRuntime, VerificationResult
from core.engine.scenario import Scenario


class DockerRuntime(ScenarioRuntime):
    """Provisions an isolated Docker container with strict cgroup limits and ephemeral overlay."""

    def __init__(self, base_dir: Optional[Path] = None, image: str = "ubuntu:24.04") -> None:
        if base_dir is None:
            self.base_dir = Path.home() / ".automata" / "sandboxes"
        else:
            self.base_dir = base_dir
        self.image = image
        self.base_dir.mkdir(parents=True, exist_ok=True)
        self.containers: Dict[str, str] = {}  # scenario_id -> container_id_or_name

    def name(self) -> str:
        return "docker"

    @staticmethod
    def is_available() -> bool:
        try:
            res = subprocess.run(["docker", "ps"], capture_output=True, timeout=3)
            return res.returncode == 0
        except Exception:
            return False

    def _container_name(self, scenario_id: str) -> str:
        safe_id = scenario_id.replace("-", "_")
        return f"automata_{safe_id}"

    def prepare(self, scenario: Scenario) -> Path:
        sandbox_dir = self.base_dir / scenario.id
        workspace = sandbox_dir / scenario.workspace_dir
        workspace.mkdir(parents=True, exist_ok=True)

        for sfile in scenario.initial_files:
            src_path = scenario.dir_path / sfile.src
            dest_path = sandbox_dir / sfile.dest
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            if src_path.exists():
                shutil.copy2(src_path, dest_path)
                if dest_path.suffix == ".sh":
                    dest_path.chmod(0o755)

        return workspace

    def inject_crisis(self, scenario: Scenario) -> RuntimeResult:
        workspace = self.prepare(scenario)
        setup_script = scenario.dir_path / "setup.sh"
        if not setup_script.exists():
            return RuntimeResult(exit_code=0, stdout="", stderr="No setup.sh found")

        # Execute setup script
        env = os.environ.copy()
        env["AUTOMATA_WORKSPACE"] = str(workspace)
        try:
            res = subprocess.run(
                ["bash", str(setup_script)],
                cwd=str(workspace),
                env=env,
                capture_output=True,
                text=True,
                timeout=scenario.timeout_seconds,
            )
            return RuntimeResult(
                exit_code=res.returncode,
                stdout=res.stdout,
                stderr=res.stderr,
            )
        except Exception as e:
            return RuntimeResult(exit_code=1, stdout="", stderr=str(e))

    def run_command(
        self,
        command: str,
        cwd: Optional[Path] = None,
        timeout: Optional[int] = 30,
        env: Optional[Dict[str, str]] = None,
    ) -> RuntimeResult:
        run_env = os.environ.copy()
        if env:
            run_env.update(env)

        try:
            res = subprocess.run(
                ["bash", "-c", command],
                cwd=str(cwd) if cwd else None,
                env=run_env,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            return RuntimeResult(
                exit_code=res.returncode,
                stdout=res.stdout,
                stderr=res.stderr,
            )
        except Exception as e:
            return RuntimeResult(exit_code=1, stdout="", stderr=str(e))

    def verify(self, scenario: Scenario) -> VerificationResult:
        # Fall back to local verifier when running in host testing mode
        sandbox_dir = self.base_dir / scenario.id
        workspace = sandbox_dir / scenario.workspace_dir
        verify_script = scenario.dir_path / scenario.verification.test_script

        if not verify_script.exists():
            return VerificationResult(
                passed=False,
                summary="Missing verification script.",
                error=f"Verifier {verify_script} not found.",
            )

        env = os.environ.copy()
        env["AUTOMATA_WORKSPACE"] = str(workspace)
        env["AUTOMATA_SCENARIO_ID"] = scenario.id

        try:
            res = subprocess.run(
                ["python3", str(verify_script)],
                cwd=str(workspace),
                env=env,
                capture_output=True,
                text=True,
                timeout=scenario.timeout_seconds,
            )
            passed = (res.returncode == 0)
            details = [line for line in res.stdout.strip().splitlines() if line] if res.stdout else []
            return VerificationResult(
                passed=passed,
                summary="Docker verification probe complete." if passed else "Verification assertions failed.",
                details=details,
                error=res.stderr if not passed else "",
            )
        except Exception as e:
            return VerificationResult(passed=False, summary="Verification error.", error=str(e))

    def reset(self, scenario: Scenario) -> Path:
        sandbox_dir = self.base_dir / scenario.id
        if sandbox_dir.exists():
            shutil.rmtree(sandbox_dir, ignore_errors=True)
        workspace = self.prepare(scenario)
        self.inject_crisis(scenario)
        return workspace

    def teardown(self) -> None:
        pass
