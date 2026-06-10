"""Конфігурація бота зі змінних оточення (.env). Жодних секретів у коді."""
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Config:
    bot_token: str
    fsolar_username: str
    fsolar_password: str
    device_sn: str
    device_type: str
    allowed_chat_id: int | None
    poll_interval_minutes: int
    db_path: str


def load_config() -> Config:
    def required(key: str) -> str:
        value = os.environ.get(key, "").strip()
        if not value:
            raise SystemExit(f"Відсутня обовʼязкова змінна оточення: {key}")
        return value

    allowed = os.environ.get("ALLOWED_CHAT_ID", "").strip()
    return Config(
        bot_token=required("TELEGRAM_BOT_TOKEN"),
        fsolar_username=required("FSOLAR_USERNAME"),
        fsolar_password=required("FSOLAR_PASSWORD"),
        device_sn=required("FSOLAR_DEVICE_SN"),
        device_type=os.environ.get("FSOLAR_DEVICE_TYPE", "OG").strip() or "OG",
        allowed_chat_id=int(allowed) if allowed else None,
        poll_interval_minutes=int(os.environ.get("POLL_INTERVAL_MINUTES", "3")),
        db_path=os.environ.get("DB_PATH", "/data/bot.db").strip() or "/data/bot.db",
    )
