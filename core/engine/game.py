"""Interactive Terminal Game Engine for Bash Automata."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

from core.engine.runner import AutomataRunner
from core.engine.scenario import Scenario
from core.ui.terminal import Colors, UI


class InteractiveGame:
    """Full-screen interactive menu wargame launcher."""

    def __init__(self, runner: Optional[AutomataRunner] = None) -> None:
        self.runner = runner or AutomataRunner()

    def run(self) -> None:
        while True:
            self._print_header()
            print("  " + UI.colorize("▶ MAIN COMMAND OPERATIONS", Colors.BRIGHT_WHITE, Colors.BOLD))
            print()
            print("  [1] 🔰 " + UI.colorize("The Academy", Colors.BRIGHT_GREEN, Colors.BOLD) + " (Foundational Drills & Step-by-Step Tutorials)")
            print("  [2] ⚔️ " + UI.colorize("The Incident Campaign", Colors.BRIGHT_RED, Colors.BOLD) + " (Hardcore Wargame Acts I - VI)")
            print("  [3] 📊 Command Center Status")
            print("  [4] 🩺 Run Diagnostic Doctor")
            print("  [q] 🚪 Exit Automata")
            print()

            choice = input("  >> Select operation [1-4, q]: ").strip().lower()

            if choice in ("q", "quit", "exit"):
                print(UI.colorize("\n  [SESSION TERMINATED] Automata Command Center offline.\n", Colors.DIM))
                break
            elif choice == "1":
                self._mission_select_menu(act_filter=0)
            elif choice == "2":
                self._mission_select_menu(act_filter=None)
            elif choice == "3":
                self.runner.status()
                input("\n  Press Enter to return to main menu...")
            elif choice == "4":
                self.runner.doctor()
                input("\n  Press Enter to return to main menu...")
            else:
                UI.warning("Invalid selection. Try again.")

    def _print_header(self) -> None:
        print("\033[H\033[J", end="")  # Clear screen cleanly
        print(UI.banner())

    def _mission_select_menu(self, act_filter: Optional[int] = None) -> None:
        while True:
            self._print_header()
            all_scenarios = self.runner.registry.list_all()

            if act_filter == 0:
                scenarios = [s for s in all_scenarios if s.act == 0]
                title = "THE ACADEMY (FOUNDATIONAL DRILLS & TUTORIALS)"
            elif act_filter is not None:
                scenarios = [s for s in all_scenarios if s.act == act_filter]
                title = f"CAMPAIGN MISSIONS (ACT {act_filter})"
            else:
                scenarios = [s for s in all_scenarios if s.act > 0]
                title = "THE INCIDENT WARGAME CAMPAIGN (ACTS I - VI)"

            if not scenarios:
                if act_filter == 0:
                    UI.warning("Academy tutorial modules are being provisioned.")
                else:
                    UI.warning("No campaign scenarios currently available.")
                input("\nPress Enter to return...")
                return

            print("  " + UI.colorize(f"▶ {title}", Colors.BRIGHT_WHITE, Colors.BOLD))
            print()

            progress_map = {row["scenario_id"]: row for row in self.runner.state.get_all_scenarios()}

            for idx, s in enumerate(scenarios, 1):
                rec = progress_map.get(s.id)
                status_str = rec["status"] if rec else "unstarted"
                if status_str == "verified":
                    badge = UI.colorize("[VERIFIED]", Colors.BRIGHT_GREEN, Colors.BOLD)
                elif status_str == "in_progress":
                    badge = UI.colorize("[IN PROGRESS]", Colors.BRIGHT_YELLOW, Colors.BOLD)
                elif status_str == "failed":
                    badge = UI.colorize("[FAILED]", Colors.BRIGHT_RED, Colors.BOLD)
                else:
                    badge = UI.colorize("[UNSTARTED]", Colors.DIM)

                print(f"  [{idx}] {badge} Act {s.act}: {s.title} ({s.id})")

            print("  [b] ⬅️ Back to Main Menu")
            print()

            choice = input(f"  >> Select scenario [1-{len(scenarios)}, b]: ").strip().lower()

            if choice in ("b", "back", "q"):
                break

            if choice.isdigit():
                val = int(choice)
                if 1 <= val <= len(scenarios):
                    target = scenarios[val - 1]
                    self._play_scenario(target)
                else:
                    UI.warning("Invalid scenario number.")
            else:
                UI.warning("Invalid selection.")

    def _play_scenario(self, scenario: Scenario) -> None:
        while True:
            self._print_header()
            rec = self.runner.state.get_scenario(scenario.id)
            status_str = rec["status"] if rec else "unstarted"
            attempts = rec["attempts"] if rec else 0

            if status_str == "verified":
                status_badge = UI.colorize("[VERIFIED / RESOLVED]", Colors.BRIGHT_GREEN, Colors.BOLD)
            elif status_str == "in_progress":
                status_badge = UI.colorize("[IN ACTIVE CRISIS]", Colors.BRIGHT_YELLOW, Colors.BOLD)
            elif status_str == "failed":
                status_badge = UI.colorize("[CRISIS FAILED]", Colors.BRIGHT_RED, Colors.BOLD)
            else:
                status_badge = UI.colorize("[UNSTARTED]", Colors.DIM)

            print("  " + UI.colorize(f"▶ MISSION: {scenario.title.upper()} (Act {scenario.act})", Colors.BRIGHT_CYAN, Colors.BOLD))
            print(f"  Status:       {status_badge}")
            print(f"  Difficulty:   {scenario.difficulty}")
            print(f"  Attempts:     {attempts}")

            workspace = self.runner.get_workspace_path(scenario.id)
            if workspace:
                print(f"  Workspace:    {UI.colorize(str(workspace), Colors.BRIGHT_WHITE, Colors.BOLD)}")
            else:
                print(f"  Workspace:    {UI.colorize('Not yet provisioned', Colors.DIM)}")
            print()

            print("  [1] 📖 Read Mission Briefing & Criteria")
            print("  [2] 🚀 Provision / Start Crisis Sandbox")
            print("  [3] 💻 Enter Trainee Terminal (Drop into Shell)")
            print("  [4] 🧪 Run State Verification (Test Fix)")
            print("  [5] 🔄 Instant Rollback (<2s)")
            print("  [6] 💡 Request Tactical Intel (Hints)")
            print("  [7] 📜 View Reference Solution & Post-Mortem")
            print("  [b] ⬅️ Back to Mission Select")
            print()

            choice = input("  >> Select action [1-7, b]: ").strip().lower()

            if choice in ("b", "back"):
                break
            elif choice == "1":
                self.runner.read_scenario(scenario.id)
                input("\n  Press Enter to return to mission room...")
            elif choice == "2":
                self.runner.start_scenario(scenario.id)
                input("\n  Press Enter to return to mission room...")
            elif choice == "3":
                self._drop_into_shell(scenario)
            elif choice == "4":
                self.runner.verify_scenario(scenario.id)
                input("\n  Press Enter to return to mission room...")
            elif choice == "5":
                self.runner.reset_scenario(scenario.id)
                input("\n  Press Enter to return to mission room...")
            elif choice == "6":
                self.runner.hint_scenario(scenario.id)
                input("\n  Press Enter to return to mission room...")
            elif choice == "7":
                self.runner.show_solution(scenario.id)
                input("\n  Press Enter to return to mission room...")
            else:
                UI.warning("Invalid choice.")

    def _drop_into_shell(self, scenario: Scenario) -> None:
        workspace = self.runner.get_workspace_path(scenario.id)
        if not workspace:
            UI.info("Sandbox workspace not detected. Auto-provisioning first...")
            self.runner.start_scenario(scenario.id)
            workspace = self.runner.get_workspace_path(scenario.id)

        print()
        UI.heading(f"Entering Trainee Shell: {scenario.id}")
        UI.info(f"Connected to sandbox: {workspace}")
        UI.prompt("Edit and test your fix inside this shell.")
        UI.prompt("Type 'exit' or press Ctrl+D when finished to return to the wargame menu.")
        print()

        env = os.environ.copy()
        env["AUTOMATA_WORKSPACE"] = str(workspace)
        env["AUTOMATA_SCENARIO_ID"] = scenario.id
        env["PS1"] = f"\033[1;36m[automata:{scenario.id}]\033[0m \\w \\$ "

        try:
            subprocess.run(["bash", "--norc"], cwd=str(workspace), env=env)
        except Exception as e:
            UI.failure(f"Error launching shell: {e}")

        UI.success("Exited sandbox terminal session. Back in Command Center.")
