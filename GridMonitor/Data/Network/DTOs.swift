import Foundation

// MARK: - Конверт відповіді FSolar
//
// API «code-in-body»: HTTP 200, а реальний статус — у полі `code`.
//   code == 200 → успіх, корисні дані в `data`
//   code == 998 → токен протух → релогін (трактуємо як APIError.unauthorized)
//   інше        → помилка (текст у `message`)
struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: T?
}

// MARK: - Логін

/// Нас цікавить лише токен; решта величезного об'єкта data ігнорується.
struct LoginData: Decodable {
    let token: String   // напр. "Bearer_eyJ..."
}

extension LoginData {
    /// Токен містить префікс `Bearer_` і йде в заголовок `Authorization` дослівно.
    func toSession() -> Session {
        Session(token: token, expiresAt: JWT.expirationDate(fromBearerToken: token))
    }
}

// MARK: - Тривоги (device_warring_list)

struct AlarmListData: Decodable {
    let dataList: [AlarmDTO]?
}

struct AlarmDTO: Decodable {
    let warringId: String?
    let deviceSn: String?
    let warnCode: String?
    let warringName: String?
    let warringType: String?
    let dataTime: Double?     // epoch ms
    let level: Int?

    func toDomain() -> Alarm? {
        guard let warringId, let deviceSn else { return nil }
        let date = dataTime.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date(timeIntervalSince1970: 0)
        return Alarm(
            id: warringId,
            deviceSN: deviceSn,
            code: warnCode ?? "",
            name: warringName ?? "",
            type: warringType ?? "",
            date: date,
            level: level
        )
    }
}

// MARK: - Real-time дані

/// Знімок з `/device/get_device_snapshot`. Декодуємо лише потрібні для MVP поля
/// (мережа + батарея); решта (PV, температури, енергії) ігнорується.
///
/// Значення приходять рядками ("218.3"), тому парсимо через Double(String).
struct RealtimeDTO: Decodable {
    // Мережа (AC-in, R-фаза для 1-фазного off-grid)
    let acRInVolt: String?
    let acRInFreq: String?
    let workMode: Int?
    let workModeStr: String?
    // Батарея — реальні дані в EMS-полях (BMS battSoc/battVolt бувають null)
    let emsSoc: String?
    let emsSocAvg: String?
    let battSoc: String?
    let emsVoltage: String?
    let emsCurrent: String?
    // Час знімку
    let dataTime: Double?

    /// Поріг напруги мережі (В): нижче — вважаємо, що мережі немає.
    /// Діапазон входу інвертора APL:90~280В, тож 50 — безпечний поріг присутності.
    static let mainsVoltageThreshold = 50.0

    func toSnapshot(now: Date) throws -> RealtimeSnapshot {
        let timestamp = dataTime.map { Date(timeIntervalSince1970: $0 / 1000) } ?? now
        let gridVoltage = acRInVolt.flatMap(Double.init)
        let gridFreq = acRInFreq.flatMap(Double.init)

        // Стан мережі: основний сигнал — напруга на вході; як підтвердження — режим роботи.
        let voltageSaysPresent = (gridVoltage ?? 0) > Self.mainsVoltageThreshold
        let modeSaysPresent = (workModeStr ?? "").localizedCaseInsensitiveContains("line")
        let isPresent = voltageSaysPresent || modeSaysPresent

        let grid = GridStatus(
            isPresent: isPresent,
            voltage: gridVoltage,
            frequency: gridFreq,
            workMode: Self.mapWorkMode(workModeStr),
            timestamp: timestamp
        )

        let socString = emsSoc ?? emsSocAvg ?? battSoc
        let battery = BatteryStatus(
            soc: socString.flatMap { Int(Double($0) ?? -1) } ?? 0,
            voltage: emsVoltage.flatMap(Double.init),
            current: emsCurrent.flatMap(Double.init),
            timestamp: timestamp
        )
        return RealtimeSnapshot(grid: grid, battery: battery)
    }

    private static func mapWorkMode(_ str: String?) -> WorkMode {
        guard let s = str?.lowercased() else { return .unknown }
        if s.contains("line") { return .line }
        if s.contains("batt") { return .battery }
        if s.contains("bypass") { return .bypass }
        return .unknown
    }
}

// MARK: - Розбір exp із JWT

enum JWT {
    /// Дістати дату закінчення з JWT (поле `exp`). Токен може мати префікс `Bearer_`.
    static func expirationDate(fromBearerToken token: String) -> Date? {
        let raw = token.hasPrefix("Bearer_") ? String(token.dropFirst("Bearer_".count)) : token
        let parts = raw.split(separator: ".")
        guard parts.count == 3, let payload = base64URLDecode(String(parts[1])) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let exp = obj["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    private static func base64URLDecode(_ s: String) -> Data? {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        return Data(base64Encoded: b)
    }
}
