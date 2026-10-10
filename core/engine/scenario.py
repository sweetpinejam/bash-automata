"""Scenario metadata specification and loader."""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class ScenarioLimits:
    memory_limit: str = "64m"
    cpu_quota: str = "1.0"
    pids_limit: int = 50


@dataclass
class ScenarioFile:
    src: str
    dest: str


@dataclass
class ScenarioVerification:
    test_script: str = "verify.py"
    chaos_command: str = ""
    pass_criteria: List[str] = field(default_factory=list)


@dataclass
class Scenario:
    id: str
    act: int
    order: int
    title: str
    difficulty: str
    timeout_seconds: int
    briefing: Dict[str, str]
    limits: ScenarioLimits
    workspace_dir: str
    initial_files: List[ScenarioFile]
    verification: ScenarioVerification
    dir_path: Path
    hints: List[str] = field(default_factory=list)

    @classmethod
    def from_dict(cls, data: Dict[str, Any], dir_path: Path) -> Scenario:
        limits_raw = data.get("limits", {})
        limits = ScenarioLimits(
            memory_limit=str(limits_raw.get("memory_limit", "64m")),
            cpu_quota=str(limits_raw.get("cpu_quota", "1.0")),
            pids_limit=int(limits_raw.get("pids_limit", 50)),
        )

        files_raw = data.get("files", {})
        workspace_dir = files_raw.get("workspace_dir", "workspace")
        initial_files = [
            ScenarioFile(src=f.get("src", ""), dest=f.get("dest", ""))
            for f in files_raw.get("initial_files", [])
            if isinstance(f, dict)
        ]

        verif_raw = data.get("verification", {})
        verification = ScenarioVerification(
            test_script=verif_raw.get("test_script", "verify.py"),
            chaos_command=verif_raw.get("chaos_command", ""),
            pass_criteria=verif_raw.get("pass_criteria", []),
        )

        hints = [str(h) for h in data.get("hints", [])]

        return cls(
            id=data.get("id", dir_path.name),
            act=int(data.get("act", 1)),
            order=int(data.get("order", 1)),
            title=data.get("title", dir_path.name),
            difficulty=data.get("difficulty", "Normal"),
            timeout_seconds=int(data.get("timeout_seconds", 300)),
            briefing=data.get("briefing", {}),
            limits=limits,
            workspace_dir=workspace_dir,
            initial_files=initial_files,
            verification=verification,
            dir_path=dir_path,
            hints=hints,
        )

    @classmethod
    def load(cls, scenario_dir: Path) -> Scenario:
        yaml_file = scenario_dir / "scenario.yaml"
        json_file = scenario_dir / "scenario.json"

        if yaml_file.exists():
            data = cls._parse_yaml(yaml_file.read_text(encoding="utf-8"))
            return cls.from_dict(data, scenario_dir)
        elif json_file.exists():
            data = json.loads(json_file.read_text(encoding="utf-8"))
            return cls.from_dict(data, scenario_dir)
        else:
            raise FileNotFoundError(f"Missing scenario definition in {scenario_dir}")

    @staticmethod
    def _parse_yaml(text: str) -> Dict[str, Any]:
        """Simple stdlib-only YAML subset parser for scenario definitions."""
        try:
            import yaml  # type: ignore

            return yaml.safe_load(text)
        except ImportError:
            pass

        def clean(val: str) -> Any:
            v = val.strip()
            if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                return v[1:-1]
            if v.lower() == "true":
                return True
            if v.lower() == "false":
                return False
            if v.isdigit():
                return int(v)
            try:
                return float(v)
            except ValueError:
                return v

        raw_lines = text.splitlines()
        items = []
        for line in raw_lines:
            s = line.rstrip()
            if not s or s.strip().startswith("#"):
                continue
            indent = len(s) - len(s.lstrip())
            items.append((indent, s.strip()))

        def parse_block(idx: int, min_indent: int) -> tuple[Any, int]:
            if idx >= len(items):
                return {}, idx

            curr_indent, curr_content = items[idx]
            if curr_content.startswith("- "):
                res_list: List[Any] = []
                while idx < len(items) and items[idx][0] == curr_indent and items[idx][1].startswith("- "):
                    line_content = items[idx][1][2:].strip()
                    idx += 1
                    is_quoted = (line_content.startswith('"') and line_content.endswith('"')) or (
                        line_content.startswith("'") and line_content.endswith("'")
                    )
                    if ":" in line_content and not is_quoted:
                        k, v = line_content.split(":", 1)
                        k, v = k.strip(), v.strip()
                        item_dict: Dict[str, Any] = {}
                        if v:
                            item_dict[k] = clean(v)
                        else:
                            sub, idx = parse_block(idx, curr_indent + 1)
                            item_dict[k] = sub
                        while idx < len(items) and items[idx][0] > curr_indent and not items[idx][1].startswith("- "):
                            sub_indent, sub_content = items[idx]
                            if ":" in sub_content:
                                sk, sv = sub_content.split(":", 1)
                                sk, sv = sk.strip(), sv.strip()
                                idx += 1
                                if sv:
                                    item_dict[sk] = clean(sv)
                                else:
                                    sub_sub, idx = parse_block(idx, sub_indent + 1)
                                    item_dict[sk] = sub_sub
                            else:
                                idx += 1
                        res_list.append(item_dict)
                    else:
                        res_list.append(clean(line_content))
                return res_list, idx
            else:
                res_dict: Dict[str, Any] = {}
                while idx < len(items) and items[idx][0] >= min_indent:
                    if items[idx][0] != min_indent:
                        break
                    line_content = items[idx][1]
                    idx += 1
                    if ":" in line_content:
                        k, v = line_content.split(":", 1)
                        k, v = k.strip(), v.strip()
                        if v:
                            res_dict[k] = clean(v)
                        else:
                            if idx < len(items) and items[idx][0] > min_indent:
                                sub, idx = parse_block(idx, items[idx][0])
                                res_dict[k] = sub
                            else:
                                res_dict[k] = {}
                return res_dict, idx

        parsed, _ = parse_block(0, 0)
        return parsed if isinstance(parsed, dict) else {}


class ScenarioRegistry:
    """Discovers and caches available scenarios across acts."""

    def __init__(self, scenarios_root: Path) -> None:
        self.scenarios_root = scenarios_root

    def list_all(self) -> List[Scenario]:
        scenarios: List[Scenario] = []
        if not self.scenarios_root.exists():
            return scenarios

        for act_dir in sorted(self.scenarios_root.glob("act-*")):
            if not act_dir.is_dir():
                continue
            for scen_dir in sorted(act_dir.iterdir()):
                if (scen_dir / "scenario.yaml").exists() or (scen_dir / "scenario.json").exists():
                    try:
                        scenarios.append(Scenario.load(scen_dir))
                    except Exception:
                        continue
        return sorted(scenarios, key=lambda s: (s.act, s.order, s.id))

    def get_by_id(self, scenario_id: str) -> Optional[Scenario]:
        for scen in self.list_all():
            if scen.id == scenario_id:
                return scen
        return None
