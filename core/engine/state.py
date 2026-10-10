"""SQLite state tracking engine for Bash Automata."""
from __future__ import annotations

import datetime
import os
import sqlite3
from pathlib import Path
from typing import Any, Dict, List, Optional


class StateManager:
    """Persistent SQLite database manager stored at ~/.automata/progress.db."""

    def __init__(self, db_path: Optional[Path] = None) -> None:
        if db_path is None:
            automata_dir = Path.home() / ".automata"
            automata_dir.mkdir(parents=True, exist_ok=True)
            self.db_path = automata_dir / "progress.db"
        else:
            self.db_path = db_path
            self.db_path.parent.mkdir(parents=True, exist_ok=True)

        self._init_db()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        with self._get_connection() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS scenario_progress (
                    scenario_id TEXT PRIMARY KEY,
                    act INTEGER NOT NULL,
                    status TEXT NOT NULL CHECK(status IN ('unstarted', 'in_progress', 'verified', 'failed')),
                    attempts INTEGER NOT NULL DEFAULT 0,
                    first_attempt_at TEXT,
                    last_attempt_at TEXT,
                    verified_at TEXT,
                    last_error TEXT,
                    sandbox_path TEXT
                )
                """
            )
            conn.commit()

    def get_scenario(self, scenario_id: str) -> Optional[Dict[str, Any]]:
        with self._get_connection() as conn:
            cur = conn.execute(
                "SELECT * FROM scenario_progress WHERE scenario_id = ?",
                (scenario_id,),
            )
            row = cur.fetchone()
            return dict(row) if row else None

    def get_all_scenarios(self) -> List[Dict[str, Any]]:
        with self._get_connection() as conn:
            cur = conn.execute(
                "SELECT * FROM scenario_progress ORDER BY act ASC, scenario_id ASC"
            )
            return [dict(row) for row in cur.fetchall()]

    def record_start(self, scenario_id: str, act: int, sandbox_path: str) -> None:
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with self._get_connection() as conn:
            existing = self.get_scenario(scenario_id)
            if existing is None:
                conn.execute(
                    """
                    INSERT INTO scenario_progress (
                        scenario_id, act, status, attempts, first_attempt_at,
                        last_attempt_at, sandbox_path
                    ) VALUES (?, ?, 'in_progress', 1, ?, ?, ?)
                    """,
                    (scenario_id, act, now, now, sandbox_path),
                )
            else:
                conn.execute(
                    """
                    UPDATE scenario_progress
                    SET status = 'in_progress',
                        attempts = attempts + 1,
                        last_attempt_at = ?,
                        sandbox_path = ?
                    WHERE scenario_id = ?
                    """,
                    (now, sandbox_path, scenario_id),
                )
            conn.commit()

    def record_verification(
        self, scenario_id: str, passed: bool, error: str = ""
    ) -> None:
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        new_status = "verified" if passed else "failed"
        with self._get_connection() as conn:
            conn.execute(
                """
                UPDATE scenario_progress
                SET status = ?,
                    verified_at = CASE WHEN ? = 1 THEN ? ELSE verified_at END,
                    last_error = ?,
                    last_attempt_at = ?
                WHERE scenario_id = ?
                """,
                (new_status, 1 if passed else 0, now, error, now, scenario_id),
            )
            conn.commit()

    def reset_scenario(self, scenario_id: str) -> None:
        with self._get_connection() as conn:
            conn.execute(
                """
                UPDATE scenario_progress
                SET status = 'unstarted',
                    last_error = NULL,
                    sandbox_path = NULL
                WHERE scenario_id = ?
                """,
                (scenario_id,),
            )
            conn.commit()

    def get_summary(self) -> Dict[str, int]:
        with self._get_connection() as conn:
            cur = conn.execute(
                """
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN status = 'verified' THEN 1 ELSE 0 END) as verified,
                    SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress,
                    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed
                FROM scenario_progress
                """
            )
            row = cur.fetchone()
            if row:
                return {
                    "total": row["total"] or 0,
                    "verified": row["verified"] or 0,
                    "in_progress": row["in_progress"] or 0,
                    "failed": row["failed"] or 0,
                }
            return {"total": 0, "verified": 0, "in_progress": 0, "failed": 0}
