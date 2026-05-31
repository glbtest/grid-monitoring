# FSolar API — контракт приватного API (Етап M0)

> **Статус:** ⛔ НЕ ЗАПОВНЕНО. Це шаблон. Його треба заповнити реальними даними,
> захопленими під вашим акаунтом FSolar. Поки тут порожні зразки — застосунок працює на
> мок-клієнті (`MockFSolarAPIClient`).
>
> Офіційного публічного API у Felicity **немає**. Нижче — інструкція, як зняти реальні
> запити, і таблиці, які треба заповнити. Після заповнення ми вмикаємо `LiveFSolarAPIClient`.

Базовий бекенд (попередньо): `https://shine-api.felicitysolar.com`
Веб-кабінет: `https://shine.felicitysolar.com/Login`

---

## Як зняти трафік (покрокова інструкція)

### Варіант A — Веб (найпростіший, пріоритетний)

1. Відкрити Chrome → `https://shine.felicitysolar.com/Login`.
2. Натиснути `F12` → вкладка **Network** → фільтр **Fetch/XHR** → увімкнути **Preserve log**.
3. Увійти своїм акаунтом FSolar.
4. Пройти весь шлях: дашборд → відкрити станцію → відкрити пристрій (інвертор) →
   real-time дані → сторінка алярмів/повідомлень.
5. Для кожного запиту в Network скопіювати:
   - **Request URL** і метод (GET/POST),
   - заголовки (особливо `Authorization`, `token`, `Cookie`),
   - тіло запиту (Payload),
   - тіло відповіді (Response) — зберегти JSON у `docs/samples/<endpoint>.json`.
6. Окремо знайти запит **логіну**: подивитись, що повертається (token? cookie?), і де він
   далі підставляється в наступні запити.

> Підказка: правою кнопкою на запиті → **Copy → Copy as cURL** — і вставити сюди. Це
> найшвидший спосіб зафіксувати точний формат.

### Варіант B — Мобільний застосунок (точніший, якщо веб неповний)

1. Поставити mitmproxy (`mitmweb`) або Charles Proxy на ПК.
2. На тестовому Android (простіше за iOS) налаштувати проксі на IP ПК і встановити
   CA-сертифікат mitmproxy як довірений.
3. Відкрити застосунок FSolar, повторити шлях з Варіанта A.
4. ⚠️ Якщо застосунок використовує **SSL-pinning** — трафік не розшифрується. Тоді
   залишаємось на Варіанті A (веб), або переходимо на запасний план (локальний Modbus).

---

## 1. Автентифікація

| Поле | Значення |
|---|---|
| URL логіну | `POST https://shine-api.felicitysolar.com/userlogin` ✅ |
| Заголовки | `Content-Type: application/json`, `lang: en_US` ✅ |
| Тіло запиту | `{ "userName": "<email>", "password": "<RSA+base64>", "version": "1.0" }` ✅ |
| Хешування пароля | **RSA (PKCS#1 v1.5) публічним ключем 2048 біт → base64** (бібліотека JSEncrypt у вебі) ✅ |
| Що повертає | `data.token` = `"Bearer_<JWT>"` ✅ |
| Заголовок авторизації наступних запитів | `Authorization: Bearer_<JWT>` — токен **дослівно** (з префіксом `Bearer_`, без пробілу) ✅ |
| TTL | ~30 діб (поле `exp` у JWT); refresh-ендпоінта немає → при протуханні релогін ✅ |

**Конверт відповідей (усі ендпоінти):** `{ "code": Int, "message": String, "data": T }`.
HTTP завжди 200; реальний статус — у `code`:
- `200` — успіх (дані в `data`);
- **`998` — токен протух → релогін** (трактуємо як unauthorized);
- інше — помилка (текст у `message`).

> ℹ️ В акаунті виявлено `openFlag:false` + `openApiPassword` — у FSolar є **офіційний Open API**
> (зараз вимкнений). Варто запитати у дилера ввімкнення — це легальніша й стабільніша
> альтернатива веб-API. Поки використовуємо веб-API.

**Публічний RSA-ключ (SubjectPublicKeyInfo, base64), зашитий у веб-застосунок:**
```
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnAJE68pjWZmtSg6ZJs9FZugJXC6bBSluTW6mJttOLOaljrdErVnM5DNN+YFzpB9pAysTErjY1bnSVuEwQSwptnqUji7Ch2qMj2n+0eCp8p6vtSh7/tFr2ul8nDRtkoswLANAIwtUk/G85ipMpmY1W642LImnEJmGkkddlbjbjxJTZWR5hc/d9cPWb+AR77LxFFrMik3c+44v1kQlIPFP6EjIbOvt/Lv7fHWD9JI/YzN4y1gK7C/VQdNGuikQyNg+5W3rg9ecYf9I5uLAQwY/hxeI3lbNsErebqKe2EbJ8AwcNIC0lDBz53Sq0ML89QapEuy3fB+upuctxLULVDCbNwIDAQAB
```
Логіка з JS (мініфіковано): `d.setPublicKey(KEY); password = d.encrypt(plaintextPassword); body = {userName, password, version:"1.0"}`.

> Реалізація в Swift: `GridMonitor/Data/Network/RSACrypto.swift` (Security.framework,
> `.rsaEncryptionPKCS1`). Ключ у форматі X.509 SPKI — перед `SecKeyCreateWithData`
> знімаємо ASN.1-заголовок до «сирого» PKCS#1 (modulus+exponent).

Зразок відповіді логіну → `docs/samples/login.json` ⛔ **ще потрібен**

---

## 2. Список станцій (plants)

| Поле | Значення |
|---|---|
| URL | `GET /___` |
| Параметри | _(pageNo, pageSize?)_ |
| Ключове поле ID станції | _(напр. `plantId` / `stationId`)_ |

Зразок → `docs/samples/plants.json`

---

## 3. Список пристроїв (devices/inverters)

| Поле | Значення |
|---|---|
| URL | `GET /___` |
| Параметри | _(plantId, ...)_ |
| Ключове поле серійника | _(напр. `deviceSN` / `sn`)_ |
| Поле типу пристрою | _(інвертор / батарея / лічильник)_ |

Зразок → `docs/samples/devices.json`

---

## 4. Real-time дані інвертора (НАЙВАЖЛИВІШЕ)

| Поле | Значення |
|---|---|
| Список пристроїв | `/deviceList` ✅ (з JS) |
| Деталі станції | `/plant/plantDetails` ✅ |
| **Real-time дані** | `POST /storageRealtimeData/display`, тіло `{"deviceSn": "<SN>"}` ✅ (з JS) |
| Альтернатива (повний знімок) | `POST /device/get_device_snapshot` ✅ (з JS) — перевірити, чи багатше за display |
| Live-потік (енергофлоу) | WebSocket `wss://shine-api.felicitysolar.com/socket/energy-flow/...` ✅ |
| Період оновлення на бекенді | ~5 хв (хмара) |

**✅ Підтверджено живим зразком `/device/get_device_snapshot`** (тіло
`{deviceSn, deviceType:"OG", dateStr:"yyyy-MM-dd HH:mm:ss"}`). Значення — рядки.
Маппінг → domain (`Data/Network/DTOs.swift` → `RealtimeDTO.toSnapshot`):

| Наше поле | Поле FSolar | Приклад | Нотатки |
|---|---|---|---|
| `GridStatus.voltage` | `acRInVolt` | "218.3" | напруга мережі (AC-in, R-фаза) |
| `GridStatus.frequency` | `acRInFreq` | "49.98" | |
| `GridStatus.workMode` | `workModeStr` | "Line Mode" | Line→.line, Battery→.battery, Bypass→.bypass |
| `BatteryStatus.soc` | `emsSoc` (→`emsSocAvg`→`battSoc`) | "99" | **BMS `battSoc` тут null → беремо EMS** |
| `BatteryStatus.voltage` | `emsVoltage` | "54" | |
| `BatteryStatus.current` | `emsCurrent` | "9" | |
| `timestamp` | `dataTime` | 1780215900000 | epoch-ms |

> ⏱️ `reportFreq: 300` — хмара оновлює дані що **5 хв**. Це стеля затримки сповіщень через
> цей ендпоінт; опитувати частіше за ~5 хв сенсу мало.

### Маппінг полів → наша domain-модель

| Наше поле | Назва поля у відповіді FSolar | Одиниці | Нотатки |
|---|---|---|---|
| `GridStatus.voltage` | `___` | В | напруга мережі / AC-in |
| `GridStatus.frequency` | `___` | Гц | |
| `GridStatus.workMode` | `___` | enum/int | які значення = Line / Battery / Bypass? |
| **прапорець наявності мережі** | `___` | bool/int | КЛЮЧОВЕ для сповіщень — див. §6 |
| `BatteryStatus.soc` | `___` | % | |
| `BatteryStatus.voltage` | `___` | В | |
| `BatteryStatus.current` | `___` | А | знак: + заряд / − розряд? |

Зразок (мережа Є) → `docs/samples/realtime_grid_on.json`
Зразок (мережа НЕМАЄ) → `docs/samples/realtime_grid_off.json`

> 💡 Зніміть два зразки: коли мережа є і коли її немає (фізично вимкнувши ввід на
> інверторі або під час реального відключення). Порівняння цих двох JSON покаже, **яке
> саме поле** надійно сигналізує про стан мережі.

---

## 5. Алярми / повідомлення

| Поле | Значення |
|---|---|
| URL | `POST /device/device_warring_list` ✅ |
| Заголовки | + `source: WEB` (крім стандартних) ✅ |
| Тіло | `{pageNum,pageSize,plantName,deviceSn,status,warringType,userName,orgCode,faultcode,deviceModel,deviceAlias,leftDate,rightDate}` — `leftDate`/`rightDate` = діапазон epoch-ms ✅ |
| Відповідь | `data.dataList[]`, плюс `data.total/totalPage/pageSize/currentPage` ✅ |
| Алярм «зникнення мережі» | **`warringName: "Abnormal Mains Power Supply"`**, `warnCode: "4"`, `warringType: "W"`, `wan1F: "[\"18\"]"` ✅ |
| Поле часу події | `dataTime` (epoch-ms) + `dataTimeStr` ✅ |
| Поле serial | `deviceSn` ✅ |
| Поле статусу | `status` (тут `1`), `statusStr` (`"0"`) — **семантика recover/handle ще не підтверджена** ⛔ |

Поля одного запису (важливі): `deviceSn, deviceModel ("IVEM12048-II"), deviceType ("OG"=off-grid),
plantId, plantName, warnCode, warringName, warringType ("W"=Warning/"F"=Fault), status, dataTime, level, timeZone`.

> **Як визначаємо «мережа зникла»:** поява нового запису з `warringName == "Abnormal Mains Power Supply"`
> (надійніше — `warnCode == "4"`) з `dataTime` новішим за останній бачений.
>
> **«Мережа з'явилась» ⛔ ще треба підтвердити:** капчурити, що приходить при відновленні —
> або новий запис зі `status=0`/окремий «recover», або поточний стан із `get_device_snapshot`.

Зразок → `docs/samples/alarms.json` ✅ (отримано)

### Ідентифікатори акаунта (для конфігурації)
- `deviceSn`: `020912004825490362` · `plantId`: `11681328210342369` · модель `IVEM12048-II` · TZ `UTC+02:00`.

---

## 6. Правило визначення «мережа Є / НЕМАЄ»

> Заповнити після §4 і §5. Обрати найнадійніше джерело.

Кандидати (обрати або скомбінувати):
- [ ] Окремий прапорець у real-time (напр. `gridConnected == 1`).
- [ ] Робочий режим (`workMode == Line/Grid` → є; `== Battery` → немає).
- [ ] Поріг напруги (`gridVoltage > 150 В` → є). _Ненадійно поодинці — як запасне._
- [ ] Окремий алярм у списку §5.

**Реалізоване правило** (`RealtimeDTO.toSnapshot`):
```
isPresent = (Double(acRInVolt) > 50) || workModeStr.contains("Line")
```
Плюс незалежний сигнал подій — журнал тривог (§5): новий `warnCode 4`
"Abnormal Mains Power Supply" = момент зникнення мережі.

⚠️ **Лишилось підтвердити grid-OFF зразком:** які саме значення `acRInVolt`/`workModeStr`
при відсутній мережі (очікуємо ~0В та "Battery Mode"). Якщо так — поріг 50В коректний.

Це правило реалізується у `Domain/UseCases/DetectGridTransition.swift` та в мапінгу
`Data/Network/DTOs.swift`.

---

## 7. Помилки та обмеження

| Код | Значення | Дія в застосунку |
|---|---|---|
| 401 | токен протух | refresh → повтор; інакше → екран логіну |
| 429 / rate-limit | забагато запитів | збільшити інтервал опитування |
| `___` | | |
