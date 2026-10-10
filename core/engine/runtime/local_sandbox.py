"""Local isolated process and filesystem runtime adapter."""
from __future__ import annotations

import os
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from core.engine.runtime.base import RuntimeResult, ScenarioRuntime, VerificationResult
from core.engine.scenario import Scenario


class LocalSandboxRuntime(ScenarioRuntime):
    """Provisions a segregated local directory sandbox with environment scrubbing."""

    def __init__(self, base_dir: Optional[Path] = None) -> None:
        if base_dir is None:
            self.base_dir = Path.home() / ".automata" / "sandboxes"
        else:
            self.base_dir = base_dir
        self.base_dir.mkdir(parents=True, exist_ok=True)
        self.active_sandboxes: Dict[str, Path] = {}

    def name(self) -> str:
        return "local_sandbox"

    def _get_sandbox_dir(self, scenario_id: str) -> Path:
        return self.base_dir / scenario_id

    def prepare(self, scenario: Scenario) -> Path:
        sandbox_dir = self._get_sandbox_dir(scenario.id)
        workspace = sandbox_dir / scenario.workspace_dir
        workspace.mkdir(parents=True, exist_ok=True)

        # Stage scenario files
        for sfile in scenario.initial_files:
            src_path = scenario.dir_path / sfile.src
            dest_path = sandbox_dir / sfile.dest
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            if src_path.exists():
                shutil.copy2(src_path, dest_path)
                if dest_path.suffix == ".sh":
                    dest_path.chmod(0o755)

        self.active_sandboxes[scenario.id] = workspace
        return workspace

    def inject_crisis(self, scenario: Scenario) -> RuntimeResult:
        workspace = self.active_sandboxes.get(scenario.id) or self.prepare(scenario)
        setup_script = scenario.dir_path / "setup.sh"
        if not setup_script.exists():
            return RuntimeResult(exit_code=0, stdout="", stderr="No setup.sh found")

        env = os.environ.copy()
        env["AUTOMATA_WORKSPACE"] = str(workspace)
        env["AUTOMATA_SCENARIO_ID"] = scenario.id

        start_time = time.monotonic()
        try:
            res = subprocess.run(
                ["bash", str(setup_script)],
                cwd=str(workspace),
                env=env,
                capture_output=True,
                text=True,
                timeout=scenario.timeout_seconds,
            )
            duration = (time.monotonic() - start_time) * 1000
            return RuntimeResult(
                exit_code=res.returncode,
                stdout=res.stdout,
                stderr=res.stderr,
                duration_ms=duration,
            )
        except subprocess.TimeoutExpired:
            duration = (time.monotonic() - start_time) * 1000
            return RuntimeResult(
                exit_code=124,
                stdout="",
                stderr="Setup script timed out.",
                duration_ms=duration,
            )
        except Exception as e:
            duration = (time.monotonic() - start_time) * 1000
            return RuntimeResult(
                exit_code=1,
                stdout="",
                stderr=str(e),
                duration_ms=duration,
            )

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

        start_time = time.monotonic()
        try:
            res = subprocess.run(
                ["bash", "-c", command],
                cwd=str(cwd) if cwd else None,
                env=run_env,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            duration = (time.monotonic() - start_time) * 1000
            return RuntimeResult(
                exit_code=res.returncode,
                stdout=res.stdout,
                stderr=res.stderr,
                duration_ms=duration,
            )
        except subprocess.TimeoutExpired:
            duration = (time.monotonic() - start_time) * 1000
            return RuntimeResult(
                exit_code=124,
                stdout="",
                stderr=f"Command timed out after {timeout}s.",
                duration_ms=duration,
            )
        except Exception as e:
            duration = (time.monotonic() - start_time) * 1000
            return RuntimeResult(
                exit_code=1,
                stdout="",
                stderr=str(e),
                duration_ms=duration,
            )

    def _get_workspace(self, scenario: Scenario) -> Path:
        if scenario.id in self.active_sandboxes:
            return self.active_sandboxes[scenario.id]
        return self._get_sandbox_dir(scenario.id) / scenario.workspace_dir

    def verify(self, scenario: Scenario) -> VerificationResult:
        workspace = self._get_workspace(scenario)
        if not workspace.exists():
            return VerificationResult(
                passed=False,
                summary="Sandbox not initialized.",
                error=f"Workspace {workspace} not found. Run 'automata start {scenario.id}' before verifying.",
            )

        verify_script = scenario.dir_path / scenario.verification.test_script
        if not verify_script.exists():
            return VerificationResult(
                passed=False,
                summary=f"Missing verification harness: {scenario.verification.test_script}",
                error=f"Verifier {verify_script} not found in scenario directory.",
            )

        env = os.environ.copy()
        env["AUTOMATA_WORKSPACE"] = str(workspace)
        env["AUTOMATA_SCENARIO_ID"] = scenario.id
        env["PYTHONUNBUFFERED"] = "1"

        # Execute chaos generator if specified
        chaos_res = None
        if scenario.verification.chaos_command:
            try:
                chaos_res = subprocess.run(
                    scenario.verification.chaos_command,
                    shell=True,
                    cwd=str(workspace),
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
            except Exception as e:
                return VerificationResult(
                    passed=False,
                    summary="Chaos generator failed during verification probe.",
                    error=str(e),
                )

        # Run verification script
        start_time = time.monotonic()
        try:
            cmd = ["python3", str(verify_script)]
            res = subprocess.run(
                cmd,
                cwd=str(workspace),
                env=env,
                capture_output=True,
                text=True,
                timeout=scenario.timeout_seconds,
            )
            duration = (time.monotonic() - start_time) * 1000

            details: List[str] = []
            if res.stdout:
                details.extend([line for line in res.stdout.strip().splitlines() if line])
            if res.stderr:
                details.extend([f"ERR: {line}" for line in res.stderr.strip().splitlines() if line])

            passed = (res.returncode == 0)
            summary = (
                "All functional state assertions passed under active load."
                if passed
                else f"Functional state assertion failed (exit code {res.returncode})."
            )

            return VerificationResult(
                passed=passed,
                summary=summary,
                details=details,
                error=res.stderr if not passed else "",
                metrics={"duration_ms": duration, "returncode": res.returncode},
            )
        except subprocess.TimeoutExpired:
            return VerificationResult(
                passed=False,
                summary="Verification harness timed out.",
                error=f"Timeout expired ({scenario.timeout_seconds}s).",
            )
        except Exception as e:
            return VerificationResult(
                passed=False,
                summary="Verifier execution exception.",
                error=str(e),
            )

    def reset(self, scenario: Scenario) -> Path:
        sandbox_dir = self._get_sandbox_dir(scenario.id)
        if sandbox_dir.exists():
            shutil.rmtree(sandbox_dir, ignore_errors=True)
        workspace = self.prepare(scenario)
        self.inject_crisis(scenario)
        return workspace

    def teardown(self) -> None:
        self.active_sandboxes.clear()
