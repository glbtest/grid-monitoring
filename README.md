# GridMonitor — моніторинг електромережі (Felicity Solar)

iOS-додаток, що через хмарний бекенд **FSolar** (`shine-api.felicitysolar.com`)
підключається до інвертора Felicity Solar, показує **стан електромережі** (є/немає),
**заряд батареї**, журнал **тривог**, і сповіщає про **зникнення/появу мережі**.

Сценарій: Україна, часті відключення — користувач хоче на телефоні бачити стан живлення
та залишок заряду АКБ і отримувати сповіщення, коли мережа зникає чи з'являється.

---

## 1. Статус

Офіційного публічного API у Felicity **немає** — приватний веб-API розкодовано (reverse
engineering) зі справжніх запитів кабінету та JS-бандлу. **Етап M0 фактично завершено**;
основна логіка реалізована на реальному API.

| Можливість | Стан |
|---|---|
| Логін, авторизація, авто-релогін | ✅ реальний API |
| Стан мережі (є/немає, напруга, частота) | ✅ реальний API |
| Заряд батареї (SOC, напруга, струм) | ✅ реальний API |
| Виявлення зникнення/появи + сповіщення + історія | ✅ |
| Журнал тривог FSolar | ✅ реальний API |
| Автосписок пристроїв (`/deviceList`) | ⏳ поки серійник вводиться вручну |
| Підтвердження порогу «мережі немає» grid-OFF зразком | ⏳ |

За замовчуванням `AppEnvironment.useMock = true` (демо-дані). Для живого режиму —
див. §8.

---

## 2. Архітектура

Шарувата MVVM-архітектура, SwiftUI-first, Swift 6 strict concurrency.

```
┌─────────────────────────── Presentation (SwiftUI + @Observable VM) ──────────────────────────┐
│  Auth/Login   Dashboard(стан)   Alarms(тривоги)   History(події)   Settings                   │
└───────────────────────────────────────────┬───────────────────────────────────────────────────┘
                                             │ викликає
┌───────────────────────────── Services / Domain ──────────────────────────────────────────────┐
│  MonitoringService — один цикл: fetch → DetectGridTransition → запис у History → сповіщення    │
│  Domain models: GridStatus, BatteryStatus, RealtimeSnapshot, Alarm, GridEvent, Device          │
│  UseCases (чисті, тестовані): DetectGridTransition, DetectNewAlarms                            │
└───────────────────────────────────────────┬───────────────────────────────────────────────────┘
                                             │ через протоколи
┌────────────────────────────────── Data ──────────────────────────────────────────────────────┐
│  Network:  FSolarAPIClient (protocol) → Live (URLSession) / Mock                               │
│            RSACrypto (шифрування пароля), DTOs (+ розбір конверта code/message/data), Endpoints │
│  Auth:     SessionManager (актор: токен, релогін) + KeychainStore                              │
│  Persist:  HistoryStore (SwiftData @Model GridEvent)                                           │
└───────────────────────────────────────────┬───────────────────────────────────────────────────┘
                                             │
┌──────────────────────────────── Background ───────────────────────────────────────────────────┐
│  GridRefreshTask (BGAppRefreshTask)   NotificationScheduler (UNUserNotificationCenter)          │
└───────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Принципи:**
- Залежності — через протоколи (`FSolarAPIClient`, `NotificationScheduling`), що дає мок у тестах.
- Уся мережа — `async/await`. Стан, що мутується спільно, ізольовано в акторах
  (`SessionManager`, `LiveFSolarAPIClient`) або на `@MainActor` (`MonitoringService`, VM).
- DTO ізолюють «брудну» форму API; у domain мапимо вручну — зміни на бекенді не течуть в UI.
- Секрети (токен, логін/пароль) — лише в **Keychain**, не в UserDefaults.

---

## 3. Логіка роботи (потік даних)

### 3.1 Логін (`LoginView` → `SessionManager` → `LiveFSolarAPIClient.login`)
1. Пароль шифрується **RSA (PKCS#1 v1.5)** публічним ключем FSolar → base64
   (`RSACrypto.encrypt`, дзеркалить JSEncrypt у вебі).
2. `POST /userlogin` тілом `{userName, password, version:"1.0"}`, заголовки `lang: en_US`,
   `source: WEB`.
3. У відповіді `data.token` = `"Bearer_<JWT>"`. Зберігаємо в Keychain; з JWT парсимо `exp`.
4. Облікові дані теж у Keychain — щоб тихо релогінитись.

### 3.2 Авторизація і помилки (`send` у `LiveFSolarAPIClient`)
- Заголовок наступних запитів: `Authorization: <token>` **дослівно** (з префіксом `Bearer_`).
- API «code-in-body»: HTTP завжди 200, статус — у полі `code`:
  `200` успіх · **`998` токен протух** → `SessionManager` релогіниться й повторює запит ·
  інше → помилка з `message`.

### 3.3 Цикл моніторингу (`MonitoringService.checkOnce`)
Спільний для foreground і фону:
1. `fetchRealtime` → `POST /device/get_device_snapshot` `{deviceSn, deviceType, dateStr}`.
2. Мапінг знімку (`RealtimeDTO.toSnapshot`):
   - мережа: `acRInVolt`, `acRInFreq`, режим з `workModeStr`;
     **`isPresent = acRInVolt > 50В || workModeStr ~ "Line"`**;
   - батарея: SOC з `emsSoc` (EMS-поля; BMS `battSoc` буває null), `emsVoltage`, `emsCurrent`.
3. `DetectGridTransition`: порівняння з попереднім знімком → подія `gridLost`/`gridRestored`.
4. На подію: запис `GridEvent` у SwiftData; у фоні — локальне сповіщення.

> Хмара оновлює дані раз на **~5 хв** (`reportFreq: 300`) — реальна стеля свіжості/затримки.

### 3.4 Сповіщення
- **Foreground:** `DashboardViewModel` опитує за таймером (інтервал у Налаштуваннях), показує
  стан і банер переходу.
- **Background:** `BGAppRefreshTask` будить застосунок, робить один `checkOnce`, і на перехід
  шле локальне сповіщення. ⚠️ iOS не гарантує частоту/факт фонового запуску (див. §7).

### 3.5 Тривоги (`AlarmsView` → `fetchAlarms`)
- `POST /device/device_warring_list` за діапазон часу → список `Alarm`.
- Тривога зникнення мережі: `warnCode "4"` / `warringName "Abnormal Mains Power Supply"`
  (`Alarm.isMainsFailure`). `DetectNewAlarms` виявляє нові такі записи (незалежний сигнал).

### 3.6 «Історія» vs «Тривоги» — різні джерела
- **Історія** (`HistoryView`) — локальні події `GridEvent`, які застосунок сам зафіксував зі
  знімків (SwiftData). Працює офлайн, є тривалість відключення.
- **Тривоги** (`AlarmsView`) — журнал із сервера FSolar (потребує мережі).

---

## 4. Зведення FSolar API (деталі — `docs/fsolar-api.md`)

| Призначення | Запит |
|---|---|
| Логін | `POST /userlogin` (пароль RSA+base64) |
| Знімок real-time | `POST /device/get_device_snapshot` `{deviceSn, deviceType, dateStr}` |
| Журнал тривог | `POST /device/device_warring_list` (діапазон `leftDate/rightDate` epoch-ms) |
| Список пристроїв | `POST /deviceList` (ще не підключено) |
| Деталі станції | `POST /plant/plantDetails` |
| Live-потік | WebSocket `wss://…/socket/energy-flow/…` (не використовуємо) |

Конверт усіх відповідей: `{ "code": Int, "message": String, "data": T }`.

---

## 5. Структура файлів

```
GridMonitor/
  App/
    GridMonitorApp.swift      точка входу @main; ModelContainer; таб-бар; реєстрація BG-задачі
    AppEnvironment.swift      DI-контейнер (@Observable): client, session, notifier,
                              обраний пристрій (SN/тип), прапорець useMock, logOut
  Services/
    MonitoringService.swift   один цикл моніторингу (fetch→detect→record→notify), @MainActor
  Domain/
    Models/
      GridStatus.swift        стан мережі (+ enum WorkMode)
      BatteryStatus.swift     стан батареї (SOC/напруга/струм)
      Device.swift            Device + Plant
      Alarm.swift             тривога (+ isMainsFailure)
      GridEvent.swift         @Model подія мережі для SwiftData (gridLost/gridRestored)
    UseCases/
      DetectGridTransition.swift   чисте правило переходу мережі
      DetectNewAlarms.swift        чисте виявлення нових mains-тривог
  Data/
    Network/
      FSolarAPIClient.swift   протокол + Credentials/Session/RealtimeSnapshot
      LiveFSolarAPIClient.swift   реальні HTTP-запити (актор), розбір конверта code/998
      MockFSolarAPIClient.swift   детерміновані демо-дані (імітація зникнення мережі)
      RSACrypto.swift         RSA-шифрування пароля (Security.framework), публічний ключ FSolar
      DTOs.swift              Codable DTO + мапінг у domain + розбір JWT exp
      Endpoints.swift         базовий URL, таймаути, шляхи ендпоінтів
      APIError.swift          помилки з людськими повідомленнями (uk)
    Auth/
      SessionManager.swift    актор: логін, зберігання токена, авто-релогін на 401/998
      KeychainStore.swift     обгортка над Security.framework (Keychain)
    Persistence/
      HistoryStore.swift      запис/читання GridEvent; тривалість останнього відключення
  Features/
    Auth/LoginView.swift                екран логіну + LoginViewModel
    Dashboard/DashboardView(+VM).swift  плашка мережі + коло SOC; foreground-опитування
    Alarms/AlarmsView(+VM).swift        список тривог із сервера
    History/HistoryView.swift           локальна історія подій (SwiftData @Query)
    Settings/SettingsView.swift         інтервал, серійник/тип пристрою, тест сповіщень, вихід
  Background/
    GridRefreshTask.swift     реєстрація/планування BGAppRefreshTask
    NotificationScheduler.swift  протокол + локальні сповіщення (UNUserNotificationCenter)

GridMonitorTests/
  DetectGridTransitionTests.swift   усі переходи мережі
  DetectNewAlarmsTests.swift        фільтрація нових mains-тривог
  MonitoringServiceTests.swift      запис події + сповіщення на in-memory SwiftData

docs/fsolar-api.md          повний контракт розкодованого API
project.yml                 XcodeGen-конфіг (iOS 17+, Swift 6, BG-режими)
```

---

## 6. Екрани
1. **Логін** — акаунт FSolar (у демо-режимі — будь-який непорожній).
2. **Стан** — велика плашка «Мережа Є/НЕМАЄ» (колір), напруга/частота, коло заряду батареї,
   pull-to-refresh.
3. **Тривоги** — журнал тривог за тиждень; «Abnormal Mains Power Supply» позначається як
   «Зникнення мережі».
4. **Історія** — локальні події зникнення/появи з рівнем заряду на момент події.
5. **Налаштування** — інтервал опитування, серійник і тип пристрою, дозвіл і тест сповіщень,
   вихід.

---

## 7. Сповіщення — обмеження iOS (важливо)
- **Foreground** — миттєво (таймер опитування).
- **Background** (`BGAppRefreshTask`) — iOS **не гарантує** частоту/факт виконання; у Low Power
  Mode може не виконуватись. Тож при повністю закритому застосунку сповіщення можливі **із
  затримкою й не на 100%**. Це обмеження платформи.
- **Для миттєвих push** потрібен власний серверний реле, що постійно опитує FSolar і шле APNs.
  Архітектура готова до цього (`NotificationScheduling`). Це поза MVP.

---

## 8. Збірка та запуск

> ⚠️ Розроблено на Windows; Xcode потрібен **Mac** (Xcode 16+, iOS 17+).

```bash
brew install xcodegen          # одноразово
xcodegen generate              # генерує GridMonitor.xcodeproj з project.yml
open GridMonitor.xcodeproj
```

**Демо-режим (за замовчуванням):** просто Run — працює на `MockFSolarAPIClient`.

**Живий режим:**
1. У `GridMonitor/App/AppEnvironment.swift` → `useMock = false`.
2. Run → увійти акаунтом FSolar.
3. У **Налаштуваннях** ввести серійник інвертора та тип (Off-grid/OG) → дашборд і тривоги
   почнуть показувати реальні дані.

---

## 9. Тести
`Cmd+U` у Xcode (Swift Testing). Покривають правила переходів мережі, фільтр нових тривог і
цикл `MonitoringService` (запис події + сповіщення) на in-memory SwiftData.

---

## 10. Безпека
- Токен і облікові дані — лише в Keychain.
- Бекенд по HTTPS; ATS увімкнений.
- ℹ️ В акаунті є `openApiPassword` + `openFlag:false` — у FSolar існує **офіційний Open API**
  (вимкнений). Варто запитати дилера про ввімкнення — стабільніша й легальніша альтернатива
  веб-API.

---

## 11. Запасний план
Якщо веб-API стане недоступним (зміни на бекенді / SSL-pinning) — перейти на **локальний
Modbus** (WiFi-донгл, Modbus TCP). Це інший мережевий шар (новий клієнт за тим самим
протоколом `FSolarAPIClient`), решта застосунку лишається.
