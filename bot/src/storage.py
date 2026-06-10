"""SQLite-стан бота: підписники, останній стан мережі, історія подій."""
from __future__ import annotations

import os
import sqlite3
from datetime import datetime


class Storage:
    def __init__(self, path: str):
        directory = os.path.dirname(path)
        if directory:
            os.makedirs(directory, exist_ok=True)
        self._db = sqlite3.connect(path, check_same_thread=False)
        self._db.executescript(
            """
            CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT);
            CREATE TABLE IF NOT EXISTS subscribers (chat_id INTEGER PRIMARY KEY);
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT, ts TEXT, soc INTEGER
            );
            """
        )
        self._db.commit()

    # --- стан мережі ---

    def get_last_present(self) -> bool | None:
        row = self._db.execute("SELECT value FROM kv WHERE key='last_present'").fetchone()
        return None if row is None else row[0] == "1"

    def set_last_present(self, present: bool) -> None:
        self._db.execute(
            "INSERT INTO kv(key, value) VALUES('last_present', ?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            ("1" if present else "0",),
        )
        self._db.commit()

    # --- підписники ---

    def add_subscriber(self, chat_id: int) -> None:
        self._db.execute("INSERT OR IGNORE INTO subscribers(chat_id) VALUES(?)", (chat_id,))
        self._db.commit()

    def remove_subscriber(self, chat_id: int) -> None:
        self._db.execute("DELETE FROM subscribers WHERE chat_id=?", (chat_id,))
        self._db.commit()

    def subscribers(self) -> list[int]:
        return [r[0] for r in self._db.execute("SELECT chat_id FROM subscribers").fetchall()]

    # --- історія ---

    def add_event(self, event_type: str, soc: int | None) -> None:
        self._db.execute(
            "INSERT INTO events(type, ts, soc) VALUES(?, ?, ?)",
            (event_type, datetime.now().isoformat(timespec="seconds"), soc),
        )
        self._db.commit()

    def recent_events(self, limit: int = 10) -> list[tuple[str, str, int | None]]:
        return self._db.execute(
            "SELECT type, ts, soc FROM events ORDER BY id DESC LIMIT ?", (limit,)
        ).fetchall()
