"""Unit tests for the Automata Engine state, scenario discovery, and sandbox runtime."""
import tempfile
import unittest
from pathlib import Path

from core.engine.runtime.local_sandbox import LocalSandboxRuntime
from core.engine.scenario import ScenarioRegistry
from core.engine.state import StateManager


class TestEngine(unittest.TestCase):
    def test_state_manager_lifecycle(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            db_path = Path(tmp_dir) / "test_progress.db"
            sm = StateManager(db_path=db_path)

            # Initial state empty
            summary = sm.get_summary()
            self.assertEqual(summary["total"], 0)
            self.assertEqual(summary["verified"], 0)

            # Start scenario
            sm.record_start("act-1-01-choked-pipe", 1, "/tmp/sandbox/workspace")
            scen = sm.get_scenario("act-1-01-choked-pipe")
            self.assertIsNotNone(scen)
            self.assertEqual(scen["status"], "in_progress")
            self.assertEqual(scen["attempts"], 1)

            # Record verification pass
            sm.record_verification("act-1-01-choked-pipe", passed=True)
            scen = sm.get_scenario("act-1-01-choked-pipe")
            self.assertEqual(scen["status"], "verified")

            summary = sm.get_summary()
            self.assertEqual(summary["verified"], 1)

            # Reset
            sm.reset_scenario("act-1-01-choked-pipe")
            scen = sm.get_scenario("act-1-01-choked-pipe")
            self.assertEqual(scen["status"], "unstarted")

    def test_scenario_discovery(self):
        repo_root = Path(__file__).resolve().parent.parent
        scenarios_dir = repo_root / "scenarios"
        registry = ScenarioRegistry(scenarios_dir)

        all_scenarios = registry.list_all()
        self.assertGreaterEqual(len(all_scenarios), 1)

        choked = registry.get_by_id("act-1-01-choked-pipe")
        self.assertIsNotNone(choked)
        self.assertEqual(choked.act, 1)
        self.assertEqual(choked.title, "The Choked Pipe")
        self.assertEqual(choked.limits.memory_limit, "64m")

    def test_local_sandbox_provisioning(self):
        repo_root = Path(__file__).resolve().parent.parent
        registry = ScenarioRegistry(repo_root / "scenarios")
        scenario = registry.get_by_id("act-1-01-choked-pipe")
        self.assertIsNotNone(scenario)

        with tempfile.TemporaryDirectory() as tmp_dir:
            runtime = LocalSandboxRuntime(base_dir=Path(tmp_dir))
            workspace = runtime.prepare(scenario)

            self.assertTrue(workspace.exists())
            self.assertTrue((workspace / "ingest.sh").exists())
            self.assertTrue((workspace / "process.py").exists())

            # Reset should clean and re-stage
            workspace2 = runtime.reset(scenario)
            self.assertTrue(workspace2.exists())


if __name__ == "__main__":
    unittest.main()
