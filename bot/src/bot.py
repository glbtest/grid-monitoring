"""Telegram-бот моніторингу електромережі через FSolar (однокористувацький режим)."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import (
    Application,
    ApplicationBuilder,
    CallbackQueryHandler,
    CommandHandler,
    ContextTypes,
)

from config import Config, load_config
from detector import detect_transition
from fsolar import FSolarClient, Snapshot

logging.basicConfig(
    format="%(asctime)s %(levelname)s %(name)s: %(message)s", level=logging.INFO
)
log = logging.getLogger("gridbot")

cfg: Config = load_config()
client = FSolarClient(cfg.fsolar_username, cfg.fsolar_password, cfg.device_sn, cfg.device_type)

try:
    TZ = ZoneInfo(cfg.timezone)
except Exception:  # noqa: BLE001 — невідома назва поясу → UTC
    log.warning("Невідомий TIMEZONE=%s, використовую UTC", cfg.timezone)
    TZ = ZoneInfo("UTC")


def _local_time(dt: datetime) -> str:
    return dt.astimezone(TZ).strftime("%H:%M:%S")


# --- доступ / стан ---

def _allowed(update: Update) -> bool:
    if cfg.allowed_chat_id is None:
        return True
    return update.effective_chat is not None and update.effective_chat.id == cfg.allowed_chat_id


def _storage(context: ContextTypes.DEFAULT_TYPE):
    return context.application.bot_data["storage"]


def _menu_kb(subscribed: bool) -> InlineKeyboardMarkup:
    toggle = (
        InlineKeyboardButton("🔕 Відписатись", callback_data="unsubscribe")
        if subscribed
        else InlineKeyboardButton("🔔 Підписатись", callback_data="subscribe")
    )
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton("🔌 Стан", callback_data="status"),
            InlineKeyboardButton("🔋 Батарея", callback_data="battery"),
        ],
        [InlineKeyboardButton("🕓 Історія", callback_data="history")],
        [toggle],
    ])


# --- форматування ---

def _soc_bar(soc: int | None) -> str:
    if soc is None:
        return ""
    filled = round(soc / 10)
    return "▰" * filled + "▱" * (10 - filled)


def _fmt_status(s: Snapshot) -> str:
    grid = "🟢 Мережа Є" if s.is_present else "🔴 Мережі НЕМАЄ"
    volt = f"{s.voltage:.0f} В" if s.voltage is not None else "—"
    freq = f"{s.frequency:.2f} Гц" if s.frequency is not None else "—"
    soc = f"{s.soc}%" if s.soc is not None else "—"
    return (
        f"{grid}\n"
        f"Напруга: {volt} · Частота: {freq}\n"
        f"🔋 Батарея: {soc}\n"
        f"Оновлено: {_local_time(s.timestamp)}"
    )


def _fmt_battery(s: Snapshot) -> str:
    soc = f"{s.soc}%" if s.soc is not None else "—"
    volt = f"{s.batt_voltage:.1f} В" if s.batt_voltage is not None else "—"
    curr = f"{s.batt_current:.1f} А" if s.batt_current is not None else "—"
    power = f"{s.batt_power:.0f} Вт" if s.batt_power is not None else "—"
    load = f"{s.load_percent}%" if s.load_percent is not None else "—"
    lines = [
        f"🔋 Заряд: {soc}",
        _soc_bar(s.soc),
        f"Напруга: {volt} · Струм: {curr}",
        f"Потужність батареї: {power}",
        f"Навантаження: {load}",
        f"Оновлено: {_local_time(s.timestamp)}",
    ]
    return "\n".join(line for line in lines if line)


def _fmt_transition(event_type: str, s: Snapshot) -> str:
    soc = f" · Батарея {s.soc}%" if s.soc is not None else ""
    when = s.timestamp.astimezone(TZ).strftime("%H:%M")
    if event_type == "gridLost":
        return f"⚡️ Зникла мережа о {when}{soc}"
    return f"✅ Зʼявилась мережа о {when}{soc}"


def _fmt_history(events) -> str:
    if not events:
        return "Поки немає зафіксованих подій."
    lines = []
    for event_type, ts, soc in events:
        icon = "⚡️" if event_type == "gridLost" else "✅"
        label = "зникла" if event_type == "gridLost" else "зʼявилась"
        soc_str = f" ({soc}%)" if soc is not None else ""
        when = _local_datetime(ts)
        lines.append(f"{icon} {when} — мережа {label}{soc_str}")
    return "Останні події:\n" + "\n".join(lines)


def _local_datetime(iso_ts: str) -> str:
    """ISO-час події (UTC) → рядок у локальному поясі. Старі naive-записи лишаємо як є."""
    try:
        dt = datetime.fromisoformat(iso_ts)
    except ValueError:
        return iso_ts.replace("T", " ")
    if dt.tzinfo is not None:
        dt = dt.astimezone(TZ)
    return dt.strftime("%Y-%m-%d %H:%M")


# --- спільні дії (команда + кнопка) ---

async def _send_status(send) -> None:
    try:
        snapshot = await client.get_snapshot()
    except Exception as exc:  # noqa: BLE001
        log.warning("status failed: %s", exc)
        await send(f"⚠️ Не вдалося отримати дані: {exc}")
        return
    await send(_fmt_status(snapshot))


async def _send_battery(send) -> None:
    try:
        snapshot = await client.get_snapshot()
    except Exception as exc:  # noqa: BLE001
        log.warning("battery failed: %s", exc)
        await send(f"⚠️ Не вдалося отримати дані: {exc}")
        return
    await send(_fmt_battery(snapshot))


# --- команди ---

async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    if not _allowed(update):
        await update.message.reply_text(f"⛔ Доступ обмежено. Ваш chat_id: {chat_id}")
        return
    storage = _storage(context)
    storage.add_subscriber(chat_id)
    await update.message.reply_text(
        "✅ Підписано на сповіщення про зникнення/появу мережі.",
        reply_markup=_menu_kb(subscribed=True),
    )


async def cmd_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not _allowed(update):
        return
    subscribed = update.effective_chat.id in _storage(context).subscribers()
    await update.message.reply_text("Меню:", reply_markup=_menu_kb(subscribed))


async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if _allowed(update):
        await _send_status(update.message.reply_text)


async def cmd_battery(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if _allowed(update):
        await _send_battery(update.message.reply_text)


async def cmd_history(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if _allowed(update):
        await update.message.reply_text(_fmt_history(_storage(context).recent_events()))


async def cmd_stop(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    _storage(context).remove_subscriber(update.effective_chat.id)
    await update.message.reply_text("🔕 Відписано. /start — щоб підписатися знову.")


# --- натискання кнопок меню ---

async def on_button(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    query = update.callback_query
    await query.answer()
    if not _allowed(update):
        return
    storage = _storage(context)
    chat_id = update.effective_chat.id
    data = query.data

    if data == "status":
        await _send_status(query.message.reply_text)
    elif data == "battery":
        await _send_battery(query.message.reply_text)
    elif data == "history":
        await query.message.reply_text(_fmt_history(storage.recent_events()))
    elif data in ("subscribe", "unsubscribe"):
        if data == "subscribe":
            storage.add_subscriber(chat_id)
            await query.answer("Підписано ✅")
        else:
            storage.remove_subscriber(chat_id)
            await query.answer("Відписано 🔕")
        subscribed = chat_id in storage.subscribers()
        await query.edit_message_reply_markup(reply_markup=_menu_kb(subscribed))


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

    storage.add_event(transition, snapshot.soc, snapshot.timestamp)
    message = _fmt_transition(transition, snapshot)
    for chat_id in storage.subscribers():
        try:
            await context.bot.send_message(chat_id, message)
        except Exception as exc:  # noqa: BLE001
            log.warning("send to %s failed: %s", chat_id, exc)


async def _on_shutdown(app: Application) -> None:
    await client.aclose()


def main() -> None:
    from storage import Storage

    # Python 3.12+/3.14: run_polling() викликає asyncio.get_event_loop(), який більше не
    # створює цикл автоматично і кидає RuntimeError — створюємо його явно.
    try:
        asyncio.get_event_loop()
    except RuntimeError:
        asyncio.set_event_loop(asyncio.new_event_loop())

    app = ApplicationBuilder().token(cfg.bot_token).post_shutdown(_on_shutdown).build()
    app.bot_data["storage"] = Storage(cfg.db_path)

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("menu", cmd_menu))
    app.add_handler(CommandHandler("status", cmd_status))
    app.add_handler(CommandHandler("battery", cmd_battery))
    app.add_handler(CommandHandler("history", cmd_history))
    app.add_handler(CommandHandler("stop", cmd_stop))
    app.add_handler(CallbackQueryHandler(on_button))

    app.job_queue.run_repeating(
        poll_job,
        interval=timedelta(minutes=cfg.poll_interval_minutes),
        first=timedelta(seconds=15),
    )

    log.info("Бот стартував. Опитування кожні %s хв.", cfg.poll_interval_minutes)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
