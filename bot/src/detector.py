"""Чисте правило виявлення переходу стану мережі (порт DetectGridTransition зі Swift)."""
from __future__ import annotations


def detect_transition(previous: bool | None, current: bool) -> str | None:
    """Повертає 'gridLost'/'gridRestored' при зміні стану, інакше None.

    Перший знімок (previous is None) — базова лінія, не подія.
    """
    if previous is None:
        return None
    if previous == current:
        return None
    return "gridRestored" if current else "gridLost"
