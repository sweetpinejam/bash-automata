"""End-to-end regression tests verifying that all Act 0, Act 1, and Act 2 scenarios pass with reference solutions."""
import shutil
import tempfile
import unittest
from pathlib import Path

from core.engine.runtime.local_sandbox import LocalSandboxRuntime
from core.engine.scenario import ScenarioRegistry


class TestAllScenariosE2E(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo_root = Path(__file__).resolve().parent.parent
        cls.registry = ScenarioRegistry(cls.repo_root / "scenarios")
        cls.scenarios = sorted(
            [s for s in cls.registry.list_all() if s.act in (0, 1, 2)],
            key=lambda x: (x.act, x.order),
        )

    def test_all_scenarios_pass_with_solutions(self):
        """Provisions each scenario in an isolated sandbox, injects solution, and verifies."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            runtime = LocalSandboxRuntime(base_dir=Path(tmp_dir))
            for s in self.scenarios:
                with self.subTest(scenario=s.id, act=s.act, order=s.order):
                    workspace = runtime.prepare(s)
                    runtime.inject_crisis(s)

                    # Identify target script to replace with solution.sh
                    target_file = None
                    for f in s.initial_files:
                        if "_broken.sh" in f.src:
                            target_file = workspace.parent / f.dest
                            break
                    if not target_file:
                        for f in s.initial_files:
                            if f.dest.endswith(".sh") and not f.dest.endswith("setup.sh") and not f.dest.endswith("multi_runner.sh"):
                                target_file = workspace.parent / f.dest
                                break

                    solution_file = s.dir_path / "solution.sh"
                    self.assertTrue(
                        solution_file.exists(),
                        f"Missing solution.sh for {s.id}",
                    )
                    self.assertIsNotNone(
                        target_file,
                        f"Could not determine target script for {s.id}",
                    )

                    shutil.copy2(solution_file, target_file)
                    target_file.chmod(0o755)

                    v_result = runtime.verify(s)
                    self.assertTrue(
                        v_result.passed,
                        f"Scenario {s.id} failed verification:\nSummary: {v_result.summary}\nError: {v_result.error}\nDetails: {v_result.details}",
                    )


if __name__ == "__main__":
    unittest.main()
