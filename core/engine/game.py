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
                self._academy_module_menu()
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

    def _academy_module_menu(self) -> None:
        """Module selection submenu for The Academy (Act 0)."""
        modules = [
            ("Module 1: Variables, Quoting & String Surgery", (1, 4), "📦"),
            ("Module 2: Conditionals, Numbers & File Tests", (5, 8), "⚖️"),
            ("Module 3: Control Flow, Safe Loops & Streams", (9, 12), "🔄"),
            ("Module 4: Functions, Scoping & Argument Discipline", (13, 16), "🧩"),
            ("Module 5: Resilient Automation & Systems Traps", (17, 20), "🛡️"),
        ]

        while True:
            self._print_header()
            print("  " + UI.colorize("▶ THE ACADEMY: BOOTCAMP MODULE SELECTION", Colors.BRIGHT_WHITE, Colors.BOLD))
            print("  Master fundamental Linux mechanics and de-mine Bash traps across 5 modules.\n")

            all_scenarios = [s for s in self.runner.registry.list_all() if s.act == 0]
            progress_map = {row["scenario_id"]: row for row in self.runner.state.get_all_scenarios()}

            for idx, (title, (start_ord, end_ord), icon) in enumerate(modules, 1):
                mod_scenarios = [s for s in all_scenarios if start_ord <= s.order <= end_ord]
                verified_count = sum(1 for s in mod_scenarios if progress_map.get(s.id, {}).get("status") == "verified")
                total_count = len(mod_scenarios)

                if verified_count == total_count and total_count > 0:
                    badge = UI.colorize(f"[{verified_count}/{total_count} COMPLETE]", Colors.BRIGHT_GREEN, Colors.BOLD)
                else:
                    badge = UI.colorize(f"[{verified_count}/{total_count} NOT COMPLETE]", Colors.DIM)

                print(f"  [{idx}] {icon} {UI.colorize(title, Colors.BRIGHT_WHITE)} {badge} (Drills {start_ord:02d}-{end_ord:02d})")

            print()
            print("  [a] 📋 View All 20 Drills (Flat List)")
            print("  [b] ⬅️ Back to Main Menu")
            print()

            choice = input("  >> Select module [1-5, a, b]: ").strip().lower()
            if choice in ("b", "back", "q"):
                break
            elif choice == "a":
                self._mission_select_menu(act_filter=0)
            elif choice.isdigit():
                val = int(choice)
                if 1 <= val <= len(modules):
                    title, (start_ord, end_ord), _ = modules[val - 1]
                    self._module_drill_select_menu(title, start_ord, end_ord)
                else:
                    UI.warning("Invalid module number.")
            else:
                UI.warning("Invalid selection.")

    def _module_drill_select_menu(self, module_title: str, start_ord: int, end_ord: int) -> None:
        """Drill list submenu for a specific Academy module."""
        while True:
            self._print_header()
            all_scenarios = [s for s in self.runner.registry.list_all() if s.act == 0 and start_ord <= s.order <= end_ord]
            print("  " + UI.colorize(f"▶ {module_title.upper()}", Colors.BRIGHT_WHITE, Colors.BOLD))
            print()

            progress_map = {row["scenario_id"]: row for row in self.runner.state.get_all_scenarios()}

            for idx, s in enumerate(all_scenarios, 1):
                rec = progress_map.get(s.id)
                status_str = rec["status"] if rec else "unstarted"
                if status_str == "verified":
                    badge = UI.colorize("[COMPLETE]", Colors.BRIGHT_GREEN, Colors.BOLD)
                else:
                    badge = UI.colorize("[NOT COMPLETE]", Colors.DIM)

                print(f"  [{idx}] {badge} Drill {s.order:02d}: {s.title} ({s.id})")

            print("  [b] ⬅️ Back to Module Selection")
            print()

            choice = input(f"  >> Select drill [1-{len(all_scenarios)}, b]: ").strip().lower()

            if choice in ("b", "back", "q"):
                break

            if choice.isdigit():
                val = int(choice)
                if 1 <= val <= len(all_scenarios):
                    target = all_scenarios[val - 1]
                    self._play_scenario(target)
                else:
                    UI.warning("Invalid drill number.")
            else:
                UI.warning("Invalid selection.")

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
                    badge = UI.colorize("[COMPLETE]", Colors.BRIGHT_GREEN, Colors.BOLD)
                else:
                    badge = UI.colorize("[NOT COMPLETE]", Colors.DIM)

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
                status_badge = UI.colorize("[COMPLETE]", Colors.BRIGHT_GREEN, Colors.BOLD)
            else:
                status_badge = UI.colorize("[NOT COMPLETE]", Colors.DIM)

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
            print("  [7] 🎯 View Code Blueprint (Almost-Answer / Snippet)")
            print("  [8] 📜 View Full Reference Solution & Post-Mortem")
            print("  [b] ⬅️ Back to Mission Select")
            print()

            choice = input("  >> Select action [1-8, b]: ").strip().lower()

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
                self.runner.show_almost_answer(scenario.id)
                input("\n  Press Enter to return to mission room...")
            elif choice == "8":
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
