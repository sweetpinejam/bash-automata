"""CLI Argument Parser & Dispatcher for Bash Automata."""
from __future__ import annotations

import argparse
import sys
from typing import List, Optional

from core.engine.runner import AutomataRunner
from core.ui.terminal import UI


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="automata",
        description="Autonomous Linux Infrastructure Workbench and Incident Simulator.",
    )
    subparsers = parser.add_subparsers(dest="command", help="Available subcommands")

    # automata list
    subparsers.add_parser("list", help="List all incident scenarios and current campaign status")

    # automata status
    subparsers.add_parser("status", help="Display overview of completed, in-progress, and failed missions")

    # automata read <id>
    read_p = subparsers.add_parser("read", help="Inspect mission briefing, constraints, and criteria")
    read_p.add_argument("id", help="Scenario ID (e.g. act-1-01-choked-pipe)")

    # automata start <id>
    start_p = subparsers.add_parser("start", help="Provision sandbox and inject crisis state")
    start_p.add_argument("id", help="Scenario ID (e.g. act-1-01-choked-pipe)")

    # automata check / verify <id>
    check_p = subparsers.add_parser("check", help="Run automated functional state verification")
    check_p.add_argument("id", help="Scenario ID (e.g. act-1-01-choked-pipe)")

    verify_p = subparsers.add_parser("verify", help="Alias for 'check'")
    verify_p.add_argument("id", help="Scenario ID (e.g. act-1-01-choked-pipe)")

    # automata reset <id>
    reset_p = subparsers.add_parser("reset", help="Instant rollback to clean scenario state (<2s)")
    reset_p.add_argument("id", help="Scenario ID (e.g. act-1-01-choked-pipe)")

    # automata play / interactive
    subparsers.add_parser("play", help="Launch interactive full-screen wargame menu")

    # automata hint <id>
    hint_p = subparsers.add_parser("hint", help="Request tactical intel & hints for scenario")
    hint_p.add_argument("id", help="Scenario ID (e.g. act-1-01-choked-pipe)")

    # automata blueprint <id>
    bp_p = subparsers.add_parser("blueprint", help="View targeted code blueprint & almost-answer")
    bp_p.add_argument("id", help="Scenario ID (e.g. act-1-01-choked-pipe)")

    aa_p = subparsers.add_parser("almost-answer", help="Alias for 'blueprint'")
    aa_p.add_argument("id", help="Scenario ID (e.g. act-1-01-choked-pipe)")

    # automata solution <id>
    sol_p = subparsers.add_parser("solution", help="View full reference solution and post-mortem")
    sol_p.add_argument("id", help="Scenario ID (e.g. act-1-01-choked-pipe)")

    # automata doctor
    subparsers.add_parser("doctor", help="Audit host environment, kernel cgroups, and tools")

    return parser


def main(args: Optional[List[str]] = None) -> int:
    parser = build_parser()
    parsed = parser.parse_args(args)

    runner = AutomataRunner()

    if parsed.command is None or parsed.command == "play":
        from core.engine.game import InteractiveGame
        game = InteractiveGame(runner)
        game.run()
        return 0

    if parsed.command == "list":
        print(UI.banner())
        runner.list_scenarios()
    elif parsed.command == "status":
        print(UI.banner())
        runner.status()
    elif parsed.command == "read":
        runner.read_scenario(parsed.id)
    elif parsed.command == "start":
        runner.start_scenario(parsed.id)
    elif parsed.command in ("check", "verify"):
        runner.verify_scenario(parsed.id)
    elif parsed.command == "reset":
        runner.reset_scenario(parsed.id)
    elif parsed.command == "hint":
        runner.hint_scenario(parsed.id)
    elif parsed.command in ("blueprint", "almost-answer"):
        runner.show_almost_answer(parsed.id)
    elif parsed.command == "solution":
        runner.show_solution(parsed.id)
    elif parsed.command == "doctor":
        runner.doctor()
    else:
        parser.print_help()
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
