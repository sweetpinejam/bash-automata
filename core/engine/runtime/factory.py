"""Runtime factory for adaptive sandbox selection."""
from __future__ import annotations

from typing import Optional

from core.engine.runtime.base import ScenarioRuntime
from core.engine.runtime.container import DockerRuntime
from core.engine.runtime.local_sandbox import LocalSandboxRuntime
from core.engine.scenario import Scenario


def get_runtime(
    scenario: Optional[Scenario] = None, preferred: Optional[str] = None
) -> ScenarioRuntime:
    """Select the optimal runtime adapter based on system capability and scenario specification."""
    if preferred == "docker":
        if DockerRuntime.is_available():
            return DockerRuntime()
        # Fallback to local sandbox if docker requested but not accessible
        return LocalSandboxRuntime()

    if preferred == "local_sandbox":
        return LocalSandboxRuntime()

    # Automatic selection
    if DockerRuntime.is_available():
        return DockerRuntime()

    return LocalSandboxRuntime()
