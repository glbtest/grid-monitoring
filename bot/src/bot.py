"""Telegram-бот моніторингу електромережі через FSolar (однокористувацький режим)."""
from __future__ import annotations

import logging
from datetime import timedelta

from telegram import Update
from telegram.ext import Application, ApplicationBuilder, CommandHandler, ContextTypes

from config import Config, load_config
from detector import detect_transition
from fsolar import FSolarClient, Snapshot

logging.basicConfig(
    format="%(asctime)s %(levelname)s %(name)s: %(message)s", level=logging.INFO
)
log = logging.getLogger("gridbot")

cfg: Config = load_config()
client = FSolarClient(cfg.fsolar_username, cfg.fsolar_password, cfg.device_sn, cfg.device_type)


# --- доступ ---

def _allowed(update: Update) -> bool:
    if cfg.allowed_chat_id is None:
        return True
    return update.effective_chat is not None and update.effective_chat.id == cfg.allowed_chat_id


def _storage(context: ContextTypes.DEFAULT_TYPE):
    return context.application.bot_data["storage"]


# --- форматування ---

def _fmt_status(s: Snapshot) -> str:
    grid = "🟢 Мережа Є" if s.is_present else "🔴 Мережі НЕМАЄ"
    volt = f"{s.voltage:.0f} В" if s.voltage is not None else "—"
    freq = f"{s.frequency:.2f} Гц" if s.frequency is not None else "—"
    soc = f"{s.soc}%" if s.soc is not None else "—"
    return (
        f"{grid}\n"
        f"Напруга: {volt} · Частота: {freq}\n"
        f"🔋 Батарея: {soc}\n"
        f"Оновлено: {s.timestamp:%H:%M:%S}"
    )


def _fmt_transition(event_type: str, s: Snapshot) -> str:
    soc = f" · Батарея {s.soc}%" if s.soc is not None else ""
    when = s.timestamp.strftime("%H:%M")
    if event_type == "gridLost":
        return f"⚡️ Зникла мережа о {when}{soc}"
    return f"✅ Зʼявилась мережа о {when}{soc}"


# --- команди ---

async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    if not _allowed(update):
        await update.message.reply_text(f"⛔ Доступ обмежено. Ваш chat_id: {chat_id}")
        return
    _storage(context).add_subscriber(chat_id)
    await update.message.reply_text(
        "✅ Підписано на сповіщення про зникнення/появу мережі.\n\n"
        "Команди:\n/status — поточний стан\n/history — останні події\n/stop — відписатися"
    )


async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not _allowed(update):
        return
    try:
        snapshot = await client.get_snapshot()
    except Exception as exc:  # noqa: BLE001 — показуємо причину користувачу
        log.warning("status failed: %s", exc)
        await update.message.reply_text(f"⚠️ Не вдалося отримати дані: {exc}")
        return
    await update.message.reply_text(_fmt_status(snapshot))


async def cmd_history(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not _allowed(update):
        return
    events = _storage(context).recent_events()
    if not events:
        await update.message.reply_text("Поки немає зафіксованих подій.")
        return
    lines = []
    for event_type, ts, soc in events:
        icon = "⚡️" if event_type == "gridLost" else "✅"
        label = "зникла" if event_type == "gridLost" else "зʼявилась"
        soc_str = f" ({soc}%)" if soc is not None else ""
        lines.append(f"{icon} {ts.replace('T', ' ')} — мережа {label}{soc_str}")
    await update.message.reply_text("Останні події:\n" + "\n".join(lines))


async def cmd_stop(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    _storage(context).remove_subscriber(update.effective_chat.id)
    await update.message.reply_text("🔕 Відписано. /start — щоб підписатися знову.")


# --- фоновий поллер ---

async def poll_job(context: ContextTypes.DEFAULT_TYPE) -> None:
    storage = context.application.bot_data["storage"]
    try:
        snapshot = await client.get_snapshot()
    except Exception as exc:  # noqa: BLE001
        log.warning("poll failed: %s", exc)
        return

    previous = storage.get_last_present()
    transition = detect_transition(previous, snapshot.is_present)
    storage.set_last_present(snapshot.is_present)

    if transition is None:
        return

    storage.add_event(transition, snapshot.soc)
    message = _fmt_transition(transition, snapshot)
    for chat_id in storage.subscribers():
        try:
            await context.bot.send_message(chat_id, message)
        except Exception as exc:  # noqa: BLE001
            log.warning("send to %s failed: %s", chat_id, exc)


async def _on_shutdown(app: Application) -> None:
    await client.aclose()


def main() -> None:
    # імпорт тут, щоб тести логіки не тягли telegram-залежність зайве
    from storage import Storage

    app = ApplicationBuilder().token(cfg.bot_token).post_shutdown(_on_shutdown).build()
    app.bot_data["storage"] = Storage(cfg.db_path)

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("status", cmd_status))
    app.add_handler(CommandHandler("history", cmd_history))
    app.add_handler(CommandHandler("stop", cmd_stop))

    app.job_queue.run_repeating(
        poll_job,
        interval=timedelta(minutes=cfg.poll_interval_minutes),
        first=timedelta(seconds=15),
    )

    log.info("Бот стартував. Опитування кожні %s хв.", cfg.poll_interval_minutes)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
