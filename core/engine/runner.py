"""Incident Scenario Runner & Lifecycle Orchestrator."""
from __future__ import annotations

import sys
from pathlib import Path
from typing import Optional

from core.engine.doctor import Doctor
from core.engine.runtime.factory import get_runtime
from core.engine.scenario import ScenarioRegistry
from core.engine.state import StateManager
from core.ui.terminal import Colors, UI


class AutomataRunner:
    """Orchestrates scenario state, sandboxing, crisis setup, and verification."""

    def __init__(self, repo_root: Optional[Path] = None) -> None:
        if repo_root is None:
            self.repo_root = Path(__file__).resolve().parent.parent.parent
        else:
            self.repo_root = repo_root

        self.scenarios_dir = self.repo_root / "scenarios"
        self.registry = ScenarioRegistry(self.scenarios_dir)
        self.state = StateManager()

    def list_scenarios(self) -> None:
        scenarios = self.registry.list_all()
        if not scenarios:
            UI.warning(f"No scenarios detected in {self.scenarios_dir}")
            return

        UI.heading("Incident Mission Registry")
        headers = ["ID", "ACT", "TITLE", "DIFFICULTY", "STATUS", "ATTEMPTS"]
        rows = []

        progress_map = {row["scenario_id"]: row for row in self.state.get_all_scenarios()}

        for s in scenarios:
            rec = progress_map.get(s.id)
            status_str = rec["status"] if rec else "unstarted"
            attempts = str(rec["attempts"]) if rec else "0"

            if status_str == "verified":
                status_styled = UI.colorize("[VERIFIED]", Colors.BRIGHT_GREEN, Colors.BOLD)
            elif status_str == "in_progress":
                status_styled = UI.colorize("[IN PROGRESS]", Colors.BRIGHT_YELLOW, Colors.BOLD)
            elif status_str == "failed":
                status_styled = UI.colorize("[FAILED]", Colors.BRIGHT_RED, Colors.BOLD)
            else:
                status_styled = UI.colorize("[UNSTARTED]", Colors.DIM)

            rows.append([s.id, f"Act {s.act}", s.title, s.difficulty, status_styled, attempts])

        UI.table(headers, rows)
        UI.prompt("Use 'automata read <id>' to inspect a briefing, or 'automata start <id>' to begin.")

    def status(self) -> None:
        summary = self.state.get_summary()
        scenarios = self.registry.list_all()
        total_available = len(scenarios)

        UI.heading("Command Center Status")
        print(f" Total Registered Scenarios: {UI.colorize(str(total_available), Colors.BRIGHT_WHITE, Colors.BOLD)}")
        print(f" Verified & Resolved:        {UI.colorize(str(summary['verified']), Colors.BRIGHT_GREEN, Colors.BOLD)}")
        print(f" Currently in Crisis/Work:   {UI.colorize(str(summary['in_progress']), Colors.BRIGHT_YELLOW, Colors.BOLD)}")
        print(f" Failed Last Assertion:      {UI.colorize(str(summary['failed']), Colors.BRIGHT_RED, Colors.BOLD)}")
        print()

    def read_scenario(self, scenario_id: str) -> None:
        scenario = self.registry.get_by_id(scenario_id)
        if not scenario:
            UI.failure(f"Scenario '{scenario_id}' not found.")
            return

        lesson_file = scenario.dir_path / "lesson.md"
        if lesson_file.exists():
            UI.heading(f"TACTICAL FIELD MANUAL: {scenario.title.upper()} ({scenario.id})")
            print(f"  Act:        Act {scenario.act} | Difficulty: {scenario.difficulty} | Timeout: {scenario.timeout_seconds}s")
            print(f"  Resource Clamps: RAM: {scenario.limits.memory_limit} | CPU: {scenario.limits.cpu_quota} | PIDs: {scenario.limits.pids_limit}\n")

            content = lesson_file.read_text(encoding="utf-8")
            in_code_block = False
            for line in content.splitlines():
                if line.startswith("```"):
                    in_code_block = not in_code_block
                    print(UI.colorize(f"   {line}", Colors.DIM))
                    continue

                if in_code_block:
                    print(UI.colorize(f"   {line}", Colors.BRIGHT_GREEN))
                elif line.startswith("# "):
                    print(UI.colorize(f"\n▶ {line[2:]}", Colors.BRIGHT_CYAN, Colors.BOLD))
                elif line.startswith("## "):
                    print(UI.colorize(f"\n◆ {line[3:]}", Colors.BRIGHT_WHITE, Colors.BOLD))
                elif line.startswith("### "):
                    print(UI.colorize(f"\n  • {line[4:]}", Colors.BRIGHT_YELLOW, Colors.BOLD))
                elif line.startswith("> "):
                    print(UI.colorize(f"  ┃ {line[2:]}", Colors.YELLOW))
                elif line.startswith("* ") or line.startswith("- "):
                    print(f"   {UI.colorize('•', Colors.BRIGHT_CYAN)} {line[2:]}")
                else:
                    print(f"  {line}")
            print()
            UI.prompt(f"To begin hands-on execution, select [2] Start Sandbox or [3] Drop into Shell.")
            return

        UI.heading(f"Mission Briefing: {scenario.title} ({scenario.id})")
        print(f" Act:        Act {scenario.act}")
        print(f" Difficulty: {scenario.difficulty}")
        print(f" Timeout:    {scenario.timeout_seconds}s")
        print(f" Resource Clamps: RAM: {scenario.limits.memory_limit} | CPU: {scenario.limits.cpu_quota} | PIDs: {scenario.limits.pids_limit}")
        print()

        UI.subheading("SITUATION REPORT")
        print(f" {scenario.briefing.get('situation', 'No situation brief provided.')}\n")

        UI.subheading("PRIMARY OBJECTIVE")
        print(f" {scenario.briefing.get('objective', 'No objective provided.')}\n")

        if scenario.verification.pass_criteria:
            UI.subheading("VERIFICATION CRITERIA")
            for crit in scenario.verification.pass_criteria:
                print(f"  • {crit}")
            print()

        UI.prompt(f"To launch this crisis sandbox, execute: automata start {scenario.id}")

    def start_scenario(self, scenario_id: str) -> None:
        scenario = self.registry.get_by_id(scenario_id)
        if not scenario:
            UI.failure(f"Scenario '{scenario_id}' not found.")
            return

        UI.heading(f"Provisioning Incident Sandbox: {scenario.title}")
        runtime = get_runtime(scenario)
        UI.info(f"Selecting adaptive runtime: {runtime.name()}")

        workspace = runtime.prepare(scenario)
        UI.info(f"Sandbox staged at: {workspace}")

        UI.info("Injecting crisis state via setup.sh...")
        setup_res = runtime.inject_crisis(scenario)

        if setup_res.exit_code != 0:
            UI.warning(f"Setup returned non-zero ({setup_res.exit_code}): {setup_res.stderr.strip()}")
        else:
            UI.success("Crisis successfully injected. Environment is live.")

        self.state.record_start(scenario.id, scenario.act, str(workspace))

        print()
        UI.subheading("TRAINEE WORKSPACE READY")
        print(f" Directory: {UI.colorize(str(workspace), Colors.BRIGHT_CYAN, Colors.BOLD)}")
        print()
        UI.prompt(f"1. Navigate: cd {workspace}")
        UI.prompt("2. Inspect broken services, descriptors, and scripts.")
        UI.prompt(f"3. Verify your fix: automata check {scenario.id}")
        UI.prompt(f"4. Rollback anytime: automata reset {scenario.id}")

    def verify_scenario(self, scenario_id: str) -> None:
        scenario = self.registry.get_by_id(scenario_id)
        if not scenario:
            UI.failure(f"Scenario '{scenario_id}' not found.")
            return

        UI.heading(f"Executing State Verification: {scenario.title}")
        runtime = get_runtime(scenario)

        UI.info(f"Connecting to sandbox via {runtime.name()}...")
        UI.info(f"Executing assertion harness: {scenario.verification.test_script}")

        res = runtime.verify(scenario)

        print()
        if res.details:
            UI.subheading("TEST HARNESS OUTPUT")
            for line in res.details:
                print(f"  {line}")
            print()

        if res.passed:
            UI.success(f"INCIDENT RESOLVED: {res.summary}")
            self.state.record_verification(scenario.id, passed=True)
        else:
            UI.failure(f"VERIFICATION FAILED: {res.summary}")
            if res.error:
                print(UI.colorize(f"\n  [ERROR DETAILS]\n  {res.error}\n", Colors.RED))
            self.state.record_verification(scenario.id, passed=False, error=res.error or res.summary)

    def reset_scenario(self, scenario_id: str) -> None:
        scenario = self.registry.get_by_id(scenario_id)
        if not scenario:
            UI.failure(f"Scenario '{scenario_id}' not found.")
            return

        UI.heading(f"Instant Rollback: {scenario.title}")
        runtime = get_runtime(scenario)
        workspace = runtime.reset(scenario)
        self.state.record_start(scenario.id, scenario.act, str(workspace))
        UI.success(f"Workspace restored to pristine state in under 2s at: {workspace}")

    def hint_scenario(self, scenario_id: str) -> None:
        scenario = self.registry.get_by_id(scenario_id)
        if not scenario:
            UI.failure(f"Scenario '{scenario_id}' not found.")
            return

        UI.heading(f"Tactical Intel & Hints: {scenario.title}")
        if not scenario.hints:
            UI.info("No specific tactical hints recorded for this incident.")
            return

        for i, h in enumerate(scenario.hints, 1):
            badge = UI.colorize(f"[{i}]", Colors.BRIGHT_YELLOW, Colors.BOLD)
            print(f" {badge} {h}")
        print()

    def show_almost_answer(self, scenario_id: str) -> None:
        scenario = self.registry.get_by_id(scenario_id)
        if not scenario:
            UI.failure(f"Scenario '{scenario_id}' not found.")
            return

        blueprint_file = scenario.dir_path / "almost_answer.md"
        content = ""
        if blueprint_file.exists():
            content = blueprint_file.read_text(encoding="utf-8")
        elif scenario.almost_answer:
            content = scenario.almost_answer

        if not content.strip():
            UI.warning("No code blueprint or almost-answer recorded for this mission.")
            UI.prompt("Use tactical intel [6] or study the briefing [1] to guide your solution.")
            return

        UI.heading(f"Code Blueprint & Almost-Answer: {scenario.title}")
        UI.info("Targeted syntax pattern and mechanics (without giving the full scenario away):")
        print()
        in_code_block = False
        for line in content.splitlines():
            if line.startswith("```"):
                in_code_block = not in_code_block
                print(UI.colorize(f"   {line}", Colors.DIM))
                continue

            if in_code_block:
                print(UI.colorize(f"   {line}", Colors.BRIGHT_YELLOW))
            elif line.startswith("# "):
                print(UI.colorize(f"\n▶ {line[2:]}", Colors.BRIGHT_CYAN, Colors.BOLD))
            elif line.startswith("## "):
                print(UI.colorize(f"\n◆ {line[3:]}", Colors.BRIGHT_WHITE, Colors.BOLD))
            elif line.startswith("### "):
                print(UI.colorize(f"\n  • {line[4:]}", Colors.BRIGHT_MAGENTA, Colors.BOLD))
            elif line.startswith("> "):
                print(UI.colorize(f"  ┃ {line[2:]}", Colors.YELLOW))
            else:
                print(f"  {line}")
        print()
        UI.prompt("Apply this pattern to your script in the sandbox and run verification.")

    def show_solution(self, scenario_id: str) -> None:
        scenario = self.registry.get_by_id(scenario_id)
        if not scenario:
            UI.failure(f"Scenario '{scenario_id}' not found.")
            return

        solution_file = scenario.dir_path / "solution.sh"
        if not solution_file.exists():
            UI.warning("Reference solution not published for this mission.")
            return

        UI.heading(f"Reference Solution & Post-Mortem: {scenario.title}")
        UI.info("Studying working reference code is a core learning tool. Inspect the implementation below:")
        print()
        code = solution_file.read_text(encoding="utf-8")
        for line in code.splitlines():
            if line.startswith("#"):
                print(UI.colorize(f"  {line}", Colors.DIM))
            else:
                print(UI.colorize(f"  {line}", Colors.BRIGHT_WHITE))
        print()
        UI.prompt("You can adapt this pattern in your sandbox and re-verify anytime.")

    def get_workspace_path(self, scenario_id: str) -> Optional[Path]:
        scenario = self.registry.get_by_id(scenario_id)
        if not scenario:
            return None
        rec = self.state.get_scenario(scenario_id)
        if rec and rec.get("sandbox_path"):
            p = Path(rec["sandbox_path"])
            if p.exists():
                return p
        default_p = Path.home() / ".automata" / "sandboxes" / scenario.id / scenario.workspace_dir
        return default_p if default_p.exists() else None

    def doctor(self) -> None:
        doc = Doctor()
        doc.run_all()
