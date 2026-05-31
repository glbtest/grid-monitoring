import Foundation

/// Конфігурація мережі. Точні шляхи заповнюються після Етапу M0 (docs/fsolar-api.md).
enum API {
    /// Базовий URL бекенду FSolar (попередньо).
    static let baseURL = URL(string: "https://shine-api.felicitysolar.com")!

    static let requestTimeout: TimeInterval = 20

    /// Шляхи ендпоінтів (з reverse-engineering веб-застосунку, M0).
    /// ⚠️ `nil` = ще не підтверджено живим зразком → `LiveFSolarAPIClient` кине `.notConfigured`.
    enum Path {
        static let login = "/userlogin"                          // ✅ підтверджено
        static let devices = "/deviceList"                       // ✅ з JS (параметри — уточнити зразком)
        static let realtime = "/storageRealtimeData/display"     // ✅ з JS (відповідь — уточнити зразком)
        static let snapshot = "/device/get_device_snapshot"      // ✅ з JS (кандидат на повний знімок)
        static let alarms = "/device/device_warring_list"        // ✅ підтверджено зразком
        static let plants: String? = "/plant/plantDetails"       // ✅ з JS
    }
}
