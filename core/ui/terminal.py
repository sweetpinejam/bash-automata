"""Terminal UI and ANSI formatting utilities for Bash Automata."""
from __future__ import annotations

import os
import sys
from typing import Sequence


class Colors:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    ITALIC = "\033[3m"
    UNDERLINE = "\033[4m"

    # Foreground
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"
    WHITE = "\033[37m"

    # Bright Foreground
    BRIGHT_RED = "\033[91m"
    BRIGHT_GREEN = "\033[92m"
    BRIGHT_YELLOW = "\033[93m"
    BRIGHT_BLUE = "\033[94m"
    BRIGHT_MAGENTA = "\033[95m"
    BRIGHT_CYAN = "\033[96m"
    BRIGHT_WHITE = "\033[97m"

    # Background
    BG_RED = "\033[41m"
    BG_GREEN = "\033[42m"
    BG_YELLOW = "\033[43m"
    BG_BLUE = "\033[44m"
    BG_DARK = "\033[48;5;236m"


class UI:
    """Terminal display and wargame UI presenter."""

    @staticmethod
    def supports_color() -> bool:
        if os.environ.get("NO_COLOR"):
            return False
        return sys.stdout.isatty() or os.environ.get("TERM") in ("xterm", "xterm-256color", "screen")

    @classmethod
    def colorize(cls, text: str, *styles: str) -> str:
        if not cls.supports_color():
            return text
        return f"{''.join(styles)}{text}{Colors.RESET}"

    @classmethod
    def banner(cls) -> str:
        raw_banner = r"""
 ██████╗  █████╗ ███████╗██╗  ██╗     █████╗ ██╗   ██╗████████╗ ██████╗ ███╗   ███╗ █████╗ ████████╗ █████╗ 
 ██╔══██╗██╔══██╗██╔════╝██║  ██║    ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗████╗ ████║██╔══██╗╚══██╔══╝██╔══██╗
 ██████╔╝███████║███████╗███████║    ███████║██║   ██║   ██║   ██║   ██║██╔████╔██║███████║   ██║   ███████║
 ██╔══██╗██╔══██║╚════██║██╔══██║    ██╔══██║██║   ██║   ██║   ██║   ██║██║╚██╔╝██║██╔══██║   ██║   ██╔══██║
 ██████╔╝██║  ██║███████║██║  ██║    ██║  ██║╚██████╔╝   ██║   ╚██████╔╝██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║
 ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝
"""
        tagline = " [ AUTONOMOUS INFRASTRUCTURE WARGAME & INCIDENT RUNTIME ]"
        ver = " v0.1.0-alpha "
        styled_banner = cls.colorize(raw_banner, Colors.BRIGHT_CYAN, Colors.BOLD)
        styled_tag = cls.colorize(tagline, Colors.BRIGHT_YELLOW, Colors.BOLD)
        styled_ver = cls.colorize(ver, Colors.BG_DARK, Colors.BRIGHT_WHITE)
        return f"{styled_banner}\n{styled_tag} {styled_ver}\n"

    @classmethod
    def heading(cls, title: str) -> None:
        rule = "━" * max(40, len(title) + 6)
        print(cls.colorize(f"\n{rule}", Colors.CYAN))
        print(cls.colorize(f"  ▶ {title.upper()}", Colors.BRIGHT_WHITE, Colors.BOLD))
        print(cls.colorize(f"{rule}\n", Colors.CYAN))

    @classmethod
    def subheading(cls, title: str) -> None:
        print(cls.colorize(f"\n◆ {title}", Colors.BRIGHT_CYAN, Colors.BOLD))

    @classmethod
    def success(cls, msg: str) -> None:
        badge = cls.colorize("[RESOLVED]", Colors.BRIGHT_GREEN, Colors.BOLD)
        print(f" {badge} {msg}")

    @classmethod
    def failure(cls, msg: str) -> None:
        badge = cls.colorize("[CRISIS]", Colors.BRIGHT_RED, Colors.BOLD)
        print(f" {badge} {msg}")

    @classmethod
    def warning(cls, msg: str) -> None:
        badge = cls.colorize("[ALERT]", Colors.BRIGHT_YELLOW, Colors.BOLD)
        print(f" {badge} {msg}")

    @classmethod
    def info(cls, msg: str) -> None:
        badge = cls.colorize("[INTEL]", Colors.BRIGHT_BLUE, Colors.BOLD)
        print(f" {badge} {msg}")

    @classmethod
    def prompt(cls, msg: str) -> None:
        badge = cls.colorize(">>", Colors.BRIGHT_CYAN, Colors.BOLD)
        print(f" {badge} {msg}")

    @classmethod
    def table(cls, headers: Sequence[str], rows: Sequence[Sequence[str]]) -> None:
        """Render aligned ANSI table with borders."""
        col_widths = [len(h) for h in headers]
        for row in rows:
            for i, cell in enumerate(row):
                # Strip ANSI for width calculation
                plain_cell = cell
                col_widths[i] = max(col_widths[i], len(plain_cell))

        fmt_header = " | ".join(f"{h:<{col_widths[i]}}" for i, h in enumerate(headers))
        separator = "-+-".join("-" * w for w in col_widths)

        print(cls.colorize(fmt_header, Colors.BRIGHT_WHITE, Colors.BOLD))
        print(cls.colorize(separator, Colors.DIM))
        for row in rows:
            fmt_row = " | ".join(f"{cell:<{col_widths[i]}}" for i, cell in enumerate(row))
            print(fmt_row)
        print()
