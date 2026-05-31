# Roadmap — наступні кроки GridMonitor

Три напрями розвитку після робочого MVP (логін, стан мережі, батарея, тривоги, історія,
сповіщення; CI зелений).

## 1. SPM-пакет `GridMonitorCore` — тести на Windows (`swift test`)

Винести «чисту» логіку (лише `Foundation`) в кросплатформний пакет, який компілюється й
тестується на Windows/Linux без Apple-фреймворків.

**У Core:** моделі (`GridStatus`, `BatteryStatus`, `Device`/`Plant`, `Alarm`),
`GridEventType`, use-cases (`DetectGridTransition`, `DetectNewAlarms`), `APIError`,
значення-типи (`Credentials`, `Session`, `RealtimeSnapshot`), DTO + мапінг
(`RealtimeDTO.toSnapshot`, `AlarmDTO.toDomain`, розбір JWT, конверт `APIResponse`).

**Лишається в застосунку** (Apple-only): `RSACrypto`/`KeychainStore` (Security),
`GridEvent`@Model/`HistoryStore` (SwiftData), клієнти `FSolarAPIClient`/Live/Mock,
`SessionManager`, `MonitoringService`, нотифікації, усі Views, `AppEnvironment`.

**Кроки:** `Packages/GridMonitorCore/Package.swift` (Swift 5 mode) → перенести файли +
зробити типи `public` (з явними `public init`) → перенести чисті тести + додати тести
мапінгу DTO → підключити пакет у `project.yml` (`packages:`) → CI-job на Linux
(`swift test`). Локально на Windows: `swift test --package-path Packages/GridMonitorCore`.

## 2. PowerShell-скрипт перевірки живого API

`scripts/verify-api.ps1` (PowerShell 7+) дзеркалить застосунок: RSA-шифрує пароль тим самим
ключем, `/userlogin` → `get_device_snapshot` → `device_warring_list`, друкує поля, які ми
мапимо (`acRInVolt`, `workModeStr`, `emsSoc`…) і обчислений `isPresent`. Дає наживо з Windows
підтвердити мапінг і зловити grid-OFF. Пароль вводиться безпечно, токен не логується.

## 3. Розповсюдження на iPhone — БЕЗ платного акаунта (AltStore)

Для особистого користування платний Apple Developer і TestFlight **не потрібні**. Шлях для
Windows без Mac:

1. **CI збирає непідписаний `.ipa`** (`.github/workflows/ipa.yml`, macOS-раннер,
   `xcodebuild archive CODE_SIGNING_ALLOWED=NO` → пакування `Payload/…ipa`) і викладає
   **артефактом** — без жодного Apple-акаунта.
2. Ви качаєте `.ipa` з вкладки Actions.
3. **AltStore** (AltServer на Windows) підписує його вашим **безкоштовним Apple ID** і
   ставить на iPhone. Альтернатива — **SideStore** (оновлює підпис на самому пристрої).

**Обмеження безкоштовного підпису:** сертифікат живе **7 днів** (AltStore/SideStore
оновлюють автоматично), максимум **3** sideload-застосунки, **remote-push недоступні** — але
наш MVP на **локальних сповіщеннях + Background App Refresh**, які працюють.

**Запуск:** `git tag v0.1.0 && git push --tags` (або кнопка «Run workflow») → завантажити
артефакт → поставити через AltStore.

> Платний шлях (fastlane + TestFlight) лишається опцією на майбутнє, якщо знадобиться
> розповсюдження кільком людям; потребує Apple Developer Program і App Store Connect API key.

## Рекомендований порядок
2 (PowerShell, швидко) → 3 (CI `.ipa`, дає застосунок на телефоні) → 1 (рефакторинг у пакет).
