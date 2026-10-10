"""Abstract base definitions for the Adaptive Scenario Runtime Engine."""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

from core.engine.scenario import Scenario


@dataclass
class RuntimeResult:
    exit_code: int
    stdout: str
    stderr: str
    duration_ms: float = 0.0


@dataclass
class VerificationResult:
    passed: bool
    summary: str
    details: List[str] = field(default_factory=list)
    error: str = ""
    metrics: Dict[str, Any] = field(default_factory=dict)


class ScenarioRuntime(ABC):
    """Abstract scenario runtime driver.
    
    Can provision local isolated environments or full container/microVM instances.
    """

    @abstractmethod
    def name(self) -> str:
        """Name of the runtime adapter (e.g. 'local_sandbox', 'docker')."""
        pass

    @abstractmethod
    def prepare(self, scenario: Scenario) -> Path:
        """Provision the runtime sandbox and stage initial files."""
        pass

    @abstractmethod
    def inject_crisis(self, scenario: Scenario) -> RuntimeResult:
        """Execute setup.sh inside the runtime to simulate the incident."""
        pass

    @abstractmethod
    def run_command(
        self,
        command: str,
        cwd: Optional[Path] = None,
        timeout: Optional[int] = None,
        env: Optional[Dict[str, str]] = None,
    ) -> RuntimeResult:
        """Execute an arbitrary command within the scenario's runtime context."""
        pass

    @abstractmethod
    def verify(self, scenario: Scenario) -> VerificationResult:
        """Execute state verification assertions (verify.py) against live system state."""
        pass

    @abstractmethod
    def reset(self, scenario: Scenario) -> Path:
        """Rollback workspace to pristine state."""
        pass

    @abstractmethod
    def teardown(self) -> None:
        """Clean up background processes, sockets, FIFOs, or containers."""
        pass
